require "test_helper"

class PlanningCenterDirectoryTest < ActionDispatch::IntegrationTest
  StaticDirectorySource = Data.define(:people) do
    def each_person(&block)
      people.each(&block)
    end
  end

  test "Admin connects Planning Center and sees the connected state" do
    sign_in_as_admin
    connect

    assert_redirected_to settings_path(anchor: "settings-directory")
    follow_redirect!
    assert_select "p", text: "Connected"
    assert organizations(:st_example).reload.planning_center_connected?
  end

  test "rejected credentials fail on connect and do not show Connected" do
    sign_in_as_admin
    organization = organizations(:st_example)

    VCR.use_cassette("planning_center/unauthorized") do
      patch planning_center_directory_path, params: {
        organization: { pco_app_id: "wrong", pco_secret: "wrong" }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Planning Center didn't accept those credentials."
    assert_select "p", text: "Connected", count: 0
    assert_not organization.reload.planning_center_connected?
  end

  test "sync creates every recorded Planning Center Person and reports literal counts" do
    sign_in_as_admin
    connect
    organization = organizations(:st_example)

    assert_difference -> { organization.people.count }, 26 do
      sync_with_recording
    end

    assert organization.people.exists?(name: "Daniel Okafor", email: "daniel.okafor@grace.example")
    assert organization.people.exists?(name: "Ruth Bennett", phone: "202-555-0104")
    assert organization.people.exists?(name: "The Alvarez Family", email: nil)
    follow_redirect!
    assert_select "p", text: "26 created, 0 updated, 0 unchanged."
  end

  test "syncing twice creates no duplicates and reports unchanged People" do
    sign_in_as_admin
    connect
    organization = organizations(:st_example)
    sync_with_recording

    assert_no_difference -> { organization.people.count } do
      sync_with_recording
    end

    follow_redirect!
    assert_select "p", text: "0 created, 0 updated, 26 unchanged."
  end

  test "sync adopts a matching email without an external identity" do
    sign_in_as_admin
    connect
    organization = organizations(:st_example)
    existing = organization.people.create!(name: "Ruth Before", email: "ruth.bennett@grace.example")

    assert_difference -> { organization.people.count }, 25 do
      sync_with_recording
    end

    existing.reload
    assert_equal "Ruth Bennett", existing.name
    assert_equal "planning_center", existing.external_source
    assert existing.external_id.present?
    assert_equal 1, organization.people.where(email: "ruth.bennett@grace.example").count
  end

  test "sync updates a Person matched by Planning Center ID" do
    sign_in_as_admin
    connect
    organization = organizations(:st_example)
    existing = organization.people.create!(
      name: "Ruth Before",
      email: "old-ruth@grace.example",
      phone: "202-555-9999",
      external_source: "planning_center",
      external_id: "204576403"
    )
    assert_nil existing.last_signed_in_at

    assert_difference -> { organization.people.count }, 25 do
      sync_with_recording
    end

    existing.reload
    assert_equal "Ruth Bennett", existing.name
    assert_equal "ruth.bennett@grace.example", existing.email
    assert_equal "202-555-0104", existing.phone
  end

  test "sync leaves a removed Person removed" do
    sign_in_as_admin
    connect
    organization = organizations(:st_example)
    removed = organization.people.create!(
      name: "Ruth Before",
      email: "old-ruth@grace.example",
      external_source: "planning_center",
      external_id: "204576403",
      removed_at: Time.current
    )

    sync_with_recording

    removed.reload
    assert_not_predicate removed, :active?
    assert_equal "Ruth Before", removed.name
  end

  test "sync protects a signed-in Person email while updating their other details" do
    leader = sign_in_as_leader
    organization = organizations(:st_example)

    DirectorySync.new(organization, source_for(
      external_id: "pco-leader-1",
      name: "Leo Leader",
      email: "leo@st-example.test",
      phone: "+12025550103"
    )).call

    result = DirectorySync.new(organization, source_for(
      external_id: "pco-leader-1",
      name: "Leonard Leader",
      email: "changed@example.test",
      phone: "+12025550104"
    )).call

    leader.reload
    assert_equal "leo@st-example.test", leader.email
    assert_equal "Leonard Leader", leader.name
    assert_equal "+12025550104", leader.phone
    assert_equal "changed@example.test", result.fetch(:skipped_email_changes).sole.fetch(:skipped_email)
  end

  test "sync protects a Person email after an invitee signs in" do
    organization = organizations(:st_example)
    invitee = people(:other_volunteer)
    invitee.update!(external_source: "planning_center", external_id: "pco-invitee-1")
    invitation = organization.invitations.create!(
      project: projects(:community_meal),
      person: invitee,
      inviter: people(:leader),
      role: :volunteer
    )

    sign_in_token = invitee.generate_token_for(:sign_in)
    get sign_in_link_path(sign_in_token)
    post sign_in_link_path(sign_in_token)
    get invitation_path(invitation.generate_token_for(:access))
    assert_response :success

    result = DirectorySync.new(organization, source_for(
      external_id: "pco-invitee-1",
      name: "Vera Volunteer",
      email: "attacker@example.test",
      phone: "+12025550105"
    )).call

    assert_equal "vera@st-example.test", invitee.reload.email
    assert_equal [ {
      person_name: "Vera Volunteer",
      current_email: "vera@st-example.test",
      skipped_email: "attacker@example.test"
    } ], result.fetch(:skipped_email_changes)
  end

  test "sync protects a Person email when an older Session exists without a sign-in stamp" do
    organization = organizations(:st_example)
    person = organization.people.find(people(:other_volunteer).id)
    person.update!(external_source: "planning_center", external_id: "pco-legacy-session-1")
    person.sessions.create!(user_agent: "Legacy browser", ip_address: "192.0.2.31")
    assert_nil person.last_signed_in_at

    result = DirectorySync.new(organization, source_for(
      external_id: "pco-legacy-session-1",
      name: "Vera Volunteer",
      email: "attacker@example.test",
      phone: "+12025550105"
    )).call

    assert_equal "vera@st-example.test", person.reload.email
    assert_equal [ {
      person_name: "Vera Volunteer",
      current_email: "vera@st-example.test",
      skipped_email: "attacker@example.test"
    } ], result.fetch(:skipped_email_changes)
  end

  test "sync does not replace an Admin sign-in email" do
    organization = organizations(:st_example)
    admin = people(:admin)
    original_email = admin.email

    DirectorySync.new(organization, source_for(
      external_id: "pco-admin-1",
      name: "Ada Admin",
      email: original_email,
      phone: "+12025550101"
    )).call

    result = DirectorySync.new(organization, source_for(
      external_id: "pco-admin-1",
      name: "Ada Admin",
      email: "attacker@example.test",
      phone: "+12025550102"
    )).call

    assert_equal original_email, admin.reload.email
    assert_equal [ {
      person_name: "Ada Admin",
      current_email: "ada@st-example.test",
      skipped_email: "attacker@example.test"
    } ], result.fetch(:skipped_email_changes)

    organization.update!(
      pco_app_id: "fixture-app",
      pco_secret: "fixture-secret",
      pco_last_synced_at: Time.current,
      pco_last_sync_result: result
    )
    sign_in_as_admin
    get settings_path
    assert_select "li", text: "Ada Admin: kept ada@st-example.test; skipped attacker@example.test from Planning Center."
  end

  test "a Planning Center Person without email cannot request a sign-in link" do
    sign_in_as_admin
    connect
    sync_with_recording
    person = organizations(:st_example).people.find_by!(name: "Sofia Nguyen")

    assert_not person.can_sign_in?
    delete session_path
    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path, params: { email: "" }
      end
    end
    follow_redirect!
    assert_select "h1", "Check your email"
  end

  test "duplicate email across Planning Center records is recorded and shown" do
    sign_in_as_admin
    connect
    organization = organizations(:st_example)
    stub_request(:get, DirectorySources::PlanningCenter::PEOPLE_URL).to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: JSON.generate(
        data: [
          remote_person("1001", "First Twin", "e1"),
          remote_person("1002", "Second Twin", "e2")
        ],
        included: [
          { type: "Email", id: "e1", attributes: { address: "twins@grace.example", primary: true } },
          { type: "Email", id: "e2", attributes: { address: "twins@grace.example", primary: true } }
        ],
        links: {}
      )
    )

    assert_no_difference -> { organization.people.count } do
      perform_enqueued_jobs { post sync_planning_center_directory_path }
    end

    follow_redirect!
    assert_select "p[role=alert]", text: "Validation failed: Email is already used by someone else in this church"
    assert_equal "Validation failed: Email is already used by someone else in this church", organization.reload.pco_last_sync_error
    assert_nil organization.pco_last_synced_at
  end

  test "rejected credentials show a plain error and change no People" do
    sign_in_as_admin
    organization = organizations(:st_example)
    organization.update!(pco_app_id: "wrong", pco_secret: "wrong")

    assert_no_difference -> { organization.people.count } do
      VCR.use_cassette("planning_center/unauthorized") do
        perform_enqueued_jobs { post sync_planning_center_directory_path }
      end
    end

    assert_response :unprocessable_entity
    assert_select "p[role=alert]", text: "Planning Center didn't accept those credentials."
  end

  test "non-Admin gets 404 on Planning Center connection" do
    sign_in_as_volunteer

    get settings_path
    assert_select "#settings-directory", count: 0
    patch planning_center_directory_path, params: { organization: { pco_app_id: "app", pco_secret: "secret" } }
    assert_response :not_found
  end

  test "People directory links to Planning Center" do
    sign_in_as_admin

    get people_path

    assert_select "a[href=?]", settings_path(anchor: "settings-directory"), text: "Planning Center"
  end

  private
    def connect(app_id: "cassette-app-id", secret: "cassette-secret")
      VCR.use_cassette("planning_center/people") do
        patch planning_center_directory_path, params: {
          organization: { pco_app_id: app_id, pco_secret: secret }
        }
      end
    end

    def sync_with_recording
      VCR.use_cassette("planning_center/people", allow_playback_repeats: true) do
        perform_enqueued_jobs { post sync_planning_center_directory_path }
      end
    end

    def source_for(**attributes)
      StaticDirectorySource.new([ attributes ])
    end

    def remote_person(id, name, email_id)
      {
        type: "Person",
        id:,
        attributes: { name: },
        relationships: {
          emails: { data: [ { type: "Email", id: email_id } ] },
          phone_numbers: { data: [] }
        }
      }
    end
end
