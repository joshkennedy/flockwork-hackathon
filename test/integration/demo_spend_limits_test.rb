require "test_helper"
require_relative "../support/method_stubs"

class DemoSpendLimitsTest < ActionDispatch::IntegrationTest
  include MethodStubs

  class CountingPlannerProvider
    attr_reader :calls

    def initialize(response, responses: nil)
      @calls = 0
      @fake = Planner::Providers::Fake.new(responses || [ response ])
    end

    def call(context, &on_partial)
      @calls += 1
      @fake.call(context, &on_partial)
    end
  end

  class CountingVoiceMinter
    attr_reader :calls

    def initialize(secret = "voice-test-secret")
      @calls = 0
      @secret = secret
    end

    def call
      @calls += 1
      @secret
    end
  end

  setup do
    @original_provider = Rails.configuration.x.planner_provider
    @original_minter = Rails.configuration.x.voice_client_secret_minter
    DemoOrganization.seed!
  end

  teardown do
    Rails.configuration.x.planner_provider = @original_provider
    Rails.configuration.x.voice_client_secret_minter = @original_minter
  end

  test "planner create is bounded per demo browser session" do
    post demo_session_path(role: "leader")
    maria = people(:grace_leader)
    project = maria.memberships.leader.first!.project
    provider = CountingPlannerProvider.new(
      planner_response(card: { "question" => "What matters most?", "options" => [ "Food", "Setup" ] })
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      10.times do
        post project_planner_sessions_path(project), params: { planner_session: { description: "Plan the next step." } }
        assert_response :redirect
      end
      assert_no_difference "PlannerSession.count" do
        post project_planner_sessions_path(project), params: { planner_session: { description: "One more plan." } }
      end
      assert_redirected_to new_project_planner_session_path(project)
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 10, provider.calls

      another_browser = open_session
      another_browser.post demo_session_path(role: "leader")
      assert_difference "PlannerSession.count", 1 do
        another_browser.post project_planner_sessions_path(project),
          params: { planner_session: { description: "Plan from another browser." } }
      end
      another_browser.assert_response :redirect
      assert_equal 11, provider.calls
    end
  end

  test "start planner is bounded per person and paid generation stops at the cap" do
    post demo_session_path(role: "leader")
    provider = CountingPlannerProvider.new(
      planner_response(card: { "question" => "What matters most?", "options" => [ "Food", "Setup" ] })
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      perform_enqueued_jobs(only: PlannerStepJob) do
        10.times do
          post start_planner_projects_path, params: { planning_kind: "workday" }
          assert_response :see_other
        end
      end
      assert_equal 10, provider.calls
      assert_no_difference [ "Project.count", "PlannerSession.count" ] do
        perform_enqueued_jobs(only: PlannerStepJob) do
          post start_planner_projects_path, params: { planning_kind: "workday" }
        end
      end
      assert_redirected_to new_project_path
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 10, provider.calls
    end
  end

  test "start meal planner is bounded per person and paid generation stops at the cap" do
    post demo_session_path(role: "leader")
    provider = CountingPlannerProvider.new(
      planner_response(card: { "question" => "What matters most?", "options" => [ "Food", "Setup" ] })
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      perform_enqueued_jobs(only: PlannerStepJob) do
        10.times do
          post start_meal_planner_projects_path
          assert_response :see_other
        end
      end
      assert_equal 0, provider.calls
      assert_no_difference [ "Project.count", "PlannerSession.count" ] do
        perform_enqueued_jobs(only: PlannerStepJob) do
          post start_meal_planner_projects_path
        end
      end
      assert_redirected_to new_project_path
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 0, provider.calls
    end
  end

  test "retry generation is bounded per person and paid generation stops at the cap" do
    post demo_session_path(role: "leader")
    provider = CountingPlannerProvider.new(
      planner_response(card: { "question" => "What matters most?", "options" => [ "Food", "Setup" ] })
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      perform_enqueued_jobs(only: PlannerStepJob) do
        post start_planner_projects_path, params: { planning_kind: "workday" }
      end
      project = PlannerSession.order(:id).last!.project
      planner_session = PlannerSession.order(:id).last!
      perform_enqueued_jobs(only: PlannerStepJob) do
        9.times do
          post retry_generation_project_planner_session_path(project, planner_session),
            params: { expected_revision: planner_session.reload.generation_revision }
          assert_response :see_other
        end
      end
      assert_equal 10, provider.calls
      perform_enqueued_jobs(only: PlannerStepJob) do
        post retry_generation_project_planner_session_path(project, planner_session),
          params: { expected_revision: planner_session.reload.generation_revision }
      end
      assert_redirected_to new_project_planner_session_path(project)
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 10, provider.calls
    end
  end

  test "select answer is bounded per person and paid generation stops at the cap" do
    post demo_session_path(role: "leader")
    card_response = planner_response(
      card: { "question" => "What matters most?", "options" => [ "Food", "Setup", "Cleanup" ] }
    )
    provider = CountingPlannerProvider.new(
      card_response, responses: Array.new(70) { card_response }
    )
    Rails.configuration.x.planner_provider = provider
    with_rate_limit_store do
      perform_enqueued_jobs(only: PlannerStepJob) do
        post start_planner_projects_path, params: { planning_kind: "workday" }
      end
      project = PlannerSession.order(:id).last!.project
      planner_session = PlannerSession.order(:id).last!
      assert_equal 1, provider.calls

      60.times do
        perform_enqueued_jobs(only: PlannerStepJob) do
          post select_answer_project_planner_session_path(project, planner_session),
            params: {
              answer: "Food",
              step_index: 0,
              expected_revision: planner_session.reload.generation_revision
            }
          assert_response :see_other
        end
      end
      assert_equal 61, provider.calls

      perform_enqueued_jobs(only: PlannerStepJob) do
        post select_answer_project_planner_session_path(project, planner_session),
          params: {
            answer: "Food",
            step_index: 0,
            expected_revision: planner_session.reload.generation_revision
          }
      end
      assert_redirected_to new_project_planner_session_path(project)
      assert_equal "Too many planning requests. Try again in an hour.", flash[:alert]
      assert_equal 61, provider.calls
    end
  end

  test "voice session mint is not blocked by planner create quota" do
    post demo_session_path(role: "leader")
    maria = people(:grace_leader)
    project = maria.memberships.leader.first!.project
    minter = CountingVoiceMinter.new
    Rails.configuration.x.voice_client_secret_minter = minter
    with_rate_limit_store do
      10.times do
        post project_planner_sessions_path(project), params: { planner_session: { description: "Plan the next step." } }
        assert_response :redirect
      end
      planner_session = project.planner_sessions.order(:id).last!
      post voice_session_project_planner_session_path(project, planner_session), as: :json
      assert_response :success
      assert_equal 1, minter.calls
    end
  end

  test "voice session mint is bounded per demo browser session" do
    post demo_session_path(role: "leader")
    maria = people(:grace_leader)
    project = maria.memberships.leader.first!.project
    minter = CountingVoiceMinter.new
    Rails.configuration.x.voice_client_secret_minter = minter
    planner_session = project.planner_sessions.create!(
      started_by: maria,
      description: "Prepare the meal.",
      current_card: { "question" => "What first?", "options" => [ "Cook", "Set up" ] }
    )
    with_rate_limit_store do
      10.times do
        post voice_session_project_planner_session_path(project, planner_session), as: :json
        assert_response :success
      end
      post voice_session_project_planner_session_path(project, planner_session), as: :json
      assert_response :too_many_requests
      assert_equal 10, minter.calls

      another_browser = open_session
      another_browser.post demo_session_path(role: "leader")
      another_browser.post voice_session_project_planner_session_path(project, planner_session), as: :json
      another_browser.assert_response :success
      assert_equal 11, minter.calls
    end
  end

  test "the demo AI cap is shared by voice and message drafts" do
    post demo_session_path(role: "leader")
    organization = organizations(:grace_fellowship)
    project = organization.projects.find_by!(name: "Church Workday")
    project.update!(enabled_tools: project.enabled_tools | [ "messages" ])
    planner_session = project.planner_sessions.create!(
      started_by: people(:grace_leader),
      description: "Prepare the workday.",
      current_card: { "question" => "What first?", "options" => [ "Cook", "Set up" ] }
    )
    minter = CountingVoiceMinter.new
    draft_calls = 0
    draft_provider = lambda do |*|
      draft_calls += 1
      { "title" => "Welcome", "body" => "Review the Project." }
    end
    Rails.configuration.x.voice_client_secret_minter = minter

    with_rate_limit_store do
      assert Array.new(DemoAiLimit::HOURLY_LIMIT - 1) { DemoAiLimit.allow?(organization) }.all?

      post voice_session_project_planner_session_path(project, planner_session), as: :json
      assert_response :success
      assert_equal 1, minter.calls

      stub_method(ProjectMessageDraft, :provider, -> { draft_provider }) do
        post project_message_draft_path(project), params: { purpose: "announcement" }
      end
      assert_response :too_many_requests
      assert_select "[data-toast-entry][data-toast-kind=alert]", text: DemoAiLimit::MESSAGE
      assert_equal 0, draft_calls
    end
  end

  test "the demo AI cap stops Planner generation and keeps the manual path" do
    post demo_session_path(role: "leader")
    organization = organizations(:grace_fellowship)
    provider = CountingPlannerProvider.new(
      planner_response(card: { "question" => "What matters most?", "options" => [ "Food", "Setup" ] })
    )
    Rails.configuration.x.planner_provider = provider

    with_rate_limit_store do
      assert Array.new(DemoAiLimit::HOURLY_LIMIT) { DemoAiLimit.allow?(organization) }.all?

      perform_enqueued_jobs(only: PlannerStepJob) do
        post start_planner_projects_path, params: { planning_kind: "workday" }
      end
      assert_response :see_other
      assert_equal 0, provider.calls

      planner_session = PlannerSession.order(:id).last!
      get project_planner_session_path(planner_session.project, planner_session)
      assert_response :success
      assert_select "[role=alert]", text: /The Planner is paused\. You can keep going by hand\./
      assert_select "form[action='#{save_and_leave_project_planner_session_path(planner_session.project, planner_session)}']", text: "Keep Going by Hand"
    end
  end

  test "a demo session can create only five Invitations in ten minutes" do
    post demo_session_path(role: "admin")
    organization = organizations(:grace_fellowship)
    project = organization.projects.find_by!(name: "Church Workday")
    invitees = organization.people.where.not(email: nil)
      .where.not(id: project.memberships.select(:person_id))
      .where.not(id: project.invitations.pending.select(:person_id))
      .order(:id).limit(6).to_a

    with_rate_limit_store do
      invitees.first(5).each do |invitee|
        post project_invitations_path(project), params: {
          invitation: { person_id: invitee.id, role: "volunteer" }
        }
        assert_response :redirect
      end

      assert_no_difference -> { organization.invitations.count } do
        post project_invitations_path(project), params: {
          invitation: { person_id: invitees.fetch(5).id, role: "volunteer" }
        }
      end
      assert_response :too_many_requests
    end

    assert_equal 5, organization.invitations.where(project:, person: invitees).count
  end

  test "a demo Person signed in by magic link can create only five Invitations in ten minutes" do
    admin = sign_in_as(people(:grace_admin))
    organization = admin.organization
    project = organization.projects.find_by!(name: "Church Workday")
    invitees = organization.people.where.not(email: nil)
      .where.not(id: project.memberships.select(:person_id))
      .where.not(id: project.invitations.pending.select(:person_id))
      .order(:id).limit(6).to_a

    with_rate_limit_store do
      invitees.first(5).each do |invitee|
        post project_invitations_path(project), params: {
          invitation: { person_id: invitee.id, role: "volunteer" }
        }
        assert_response :redirect
      end

      assert_no_difference -> { organization.invitations.count } do
        post project_invitations_path(project), params: {
          invitation: { person_id: invitees.fetch(5).id, role: "volunteer" }
        }
      end
      assert_response :too_many_requests
    end

    assert_equal 5, organization.invitations.where(project:, person: invitees).count
  end

  test "a demo session can create only five People in ten minutes" do
    post demo_session_path(role: "admin")
    organization = organizations(:grace_fellowship)

    with_rate_limit_store do
      5.times do |index|
        post people_path, params: {
          person: { name: "Demo Person #{index + 1}", email: "demo-person-#{index + 1}@example.test" }
        }
        assert_response :redirect
      end

      assert_no_difference -> { organization.people.count } do
        post people_path, params: {
          person: { name: "Demo Person 6", email: "demo-person-6@example.test" }
        }
      end
      assert_response :too_many_requests
      assert_select "[data-toast-entry][data-toast-kind=alert]", text: "Demo limit reached. Try again in 10 minutes."
      assert_select "input[name='person[name]'][value='Demo Person 6']"
    end

    assert_equal 5, organization.people.where("email LIKE ?", "demo-person-%@example.test").count
  end

  test "a demo session can change its phone only five times in ten minutes" do
    post demo_session_path(role: "volunteer")
    volunteer = people(:grace_volunteer)

    with_rate_limit_store do
      5.times do |index|
        patch profile_path, params: { person: { phone: "+1555555010#{index}" } }
        assert_response :redirect
      end

      patch profile_path, params: { person: { phone: "+15555550105" } }
      assert_response :too_many_requests
    end

    assert_equal "+15555550104", volunteer.reload.phone
  end

  test "new demo sessions cannot evade the shared IP cap" do
    organization = organizations(:grace_fellowship)

    with_rate_limit_store do
      4.times do |session_index|
        post demo_session_path(role: "admin")
        5.times do |request_index|
          number = session_index * 5 + request_index + 1
          post people_path, params: {
            person: { name: "IP Person #{number}", email: "ip-person-#{number}@example.test" }
          }
          assert_response :redirect
        end
      end

      post demo_session_path(role: "admin")
      assert_no_difference -> { organization.people.count } do
        post people_path, params: {
          person: { name: "IP Person 21", email: "ip-person-21@example.test" }
        }
      end
      assert_response :too_many_requests
    end

    assert_equal 20, organization.people.where("email LIKE ?", "ip-person-%@example.test").count
  end

  test "demo outbound beyond the Organization cap stays in app" do
    post demo_session_path(role: "admin")
    organization = organizations(:grace_fellowship)
    admin = people(:grace_admin)
    project = organization.projects.find_by!(name: "Church Workday")
    leader = people(:grace_leader)
    task = project.tasks.create!(title: "Prepare welcome table", assignee: leader)
    invitee = organization.people.where.not(email: nil)
      .where.not(id: admin.id)
      .where.not(id: project.memberships.select(:person_id))
      .where.not(id: project.invitations.pending.select(:person_id))
      .order(:id).first!
    invitee.update!(phone: "+15555550100", sms_preferences: { invitation: true })
    sms_request = stub_request(:post, Messaging::Sendly::ENDPOINT.to_s)
      .to_return(status: 201, body: { id: "msg_demo", status: "delivered", simulated: true }.to_json)

    with_sendly_api_key do
      with_rate_limit_store do
        20.times do
          Notifier.notify(recipient: leader, kind: "task_assigned", notifiable: task, actor: admin)
        end
        clear_enqueued_jobs
        ActionMailer::Base.deliveries.clear

        assert_difference -> { invitee.notifications.in_app.count }, 1 do
          perform_enqueued_jobs do
            post project_invitations_path(project), params: {
              invitation: { person_id: invitee.id, role: "volunteer" }
            }
          end
        end
      end
    end

    assert_response :redirect
    assert_empty ActionMailer::Base.deliveries
    assert_not_requested sms_request
    notification = invitee.notifications.invitation.order(:id).last!
    assert_equal "cancelled", notification.sms_status
    assert_empty notification.sms_payload
  end

  test "a demo visitor inviting a new address from the Team page sends no email or text" do
    post demo_session_path(role: "admin")
    organization = organizations(:grace_fellowship)
    project = organization.projects.find_by!(name: "Church Workday")
    sms_request = stub_request(:post, Messaging::Sendly::ENDPOINT.to_s)

    with_sendly_api_key do
      with_rate_limit_store do
        perform_enqueued_jobs do
          post project_invitations_path(project), params: {
            invitation: { name: "Stranger Danger", email: "stranger@real-inbox.test", role: "volunteer" }
          }
        end
      end
    end

    assert_response :redirect
    invitee = organization.people.find_by!(email: "stranger@real-inbox.test")
    assert_equal 1, invitee.notifications.invitation.count
    assert_empty ActionMailer::Base.deliveries
    assert_not_requested sms_request
  end

  test "a demo Invitation link sends no sign-in email after the Organization cap" do
    organization = organizations(:grace_fellowship)
    inviter = people(:grace_admin)
    project = organization.projects.find_by!(name: "Church Workday")
    invitee = organization.people.create!(name: "Demo Invitee", email: "demo-invitee@example.test")
    invitation = organization.invitations.create!(
      project:,
      person: invitee,
      inviter:,
      role: "volunteer"
    )
    token = invitation.generate_token_for(:access)
    reset!

    with_rate_limit_store do
      20.times { assert DemoOutboundLimit.allow?(organization) }

      assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        get invitation_path(token)
      end
    end

    assert_response :success
    assert_select "h1", "Check your inbox"
  end

  test "a demo church's Public link sends no sign-in code after the Organization cap" do
    project = projects(:community_meal)
    project.organization.update!(demo: true)
    project.enable_public_link!

    with_rate_limit_store do
      20.times { assert DemoOutboundLimit.allow?(project.organization) }

      assert_no_enqueued_jobs only: SignInChallengeJob do
        post guest_sign_in_path(project.public_token), params: { contact: "nadia@example.com" }
      end
    end

    assert_redirected_to guest_sign_in_code_path(project.public_token)
  end

  test "a demo Person receives no sign-in email after the Organization cap" do
    organization = organizations(:grace_fellowship)
    person = people(:grace_leader)

    with_rate_limit_store do
      20.times { assert DemoOutboundLimit.allow?(organization) }

      assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        post sign_in_requests_path, params: { email: person.email }
      end
    end

    assert_redirected_to check_email_path, status: :see_other
    follow_redirect!
    assert_select "h1", "Check your email"
  end

  test "a demo Admin's email change stores the pending address but mails nothing after the Organization cap" do
    organization = organizations(:grace_fellowship)
    person = people(:grace_leader)
    post demo_session_path(role: "admin")

    with_rate_limit_store do
      20.times { assert DemoOutboundLimit.allow?(organization) }

      assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        patch person_path(person), params: { person: { name: person.name, email: "new.grace@example.test" } }
      end
    end

    assert_redirected_to person_path(person)
    assert_equal "new.grace@example.test", person.reload.pending_email
  end

  test "a non-demo Person still receives a sign-in email" do
    person = people(:leader)

    with_rate_limit_store do
      assert_enqueued_email_with SignInMailer, :sign_in_link, args: [ person ] do
        post sign_in_requests_path, params: { email: person.email }
      end
    end

    assert_redirected_to check_email_path, status: :see_other
  end

  test "non-demo Invitation creation remains unlimited" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    invitees = 6.times.map do |index|
      leader.organization.people.create!(
        name: "Invitee #{index + 1}", email: "invitee-#{index + 1}@st-example.test"
      )
    end

    with_rate_limit_store do
      invitees.each do |invitee|
        post project_invitations_path(project), params: {
          invitation: { person_id: invitee.id, role: "volunteer" }
        }
        assert_response :redirect
      end
    end

    assert_equal 6, leader.organization.invitations.where(project:, person: invitees).count
  end

  private
    def with_rate_limit_store
      store = ActiveSupport::Cache::MemoryStore.new
      increment = ->(*args, **kwargs) { store.increment(*args, **kwargs) }
      stub_method(Rails, :cache, -> { store }) do
        stub_method(PlannerSessionsController.cache_store, :increment, increment) do
          stub_method(ProjectsController.cache_store, :increment, increment) do
            stub_method(InvitationsController.cache_store, :increment, increment) do
              stub_method(PeopleController.cache_store, :increment, increment) do
                stub_method(ProfilesController.cache_store, :increment, increment) do
                  yield
                end
              end
            end
          end
        end
      end
    end

    def with_sendly_api_key
      previous_key = ENV["SENDLY_API_KEY"]
      ENV["SENDLY_API_KEY"] = "sandbox"
      yield
    ensure
      previous_key.nil? ? ENV.delete("SENDLY_API_KEY") : ENV["SENDLY_API_KEY"] = previous_key
    end

    def planner_response(card: nil, finished: false, added: [], removed_ids: [])
      Planner::Response.new(card:, finished:, added:, removed_ids:)
    end
end
