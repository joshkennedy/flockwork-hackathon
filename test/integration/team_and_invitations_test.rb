require "test_helper"
require_relative "../support/method_stubs"

class TeamAndInvitationsTest < ActionDispatch::IntegrationTest
  include MethodStubs
  test "a Leader sees the Project Team with member roles" do
    sign_in_as_leader
    project = projects(:community_meal)

    get team_project_path(project)

    assert_response :success
    assert_select "h1", "Community Meal"
    assert_select "a.tab-link[aria-current=true]", "Team"
    assert_select "li", text: /Leo Leader.*Leader/
    assert_select "li", text: /Vic Volunteer.*Volunteer/
  end

  test "a Leader sees why a Person without email or phone cannot be invited" do
    sign_in_as_leader
    project = projects(:community_meal)

    get team_project_path(project), params: { query: "Rowan" }

    assert_response :success
    assert_select "input[name='query'][value='Rowan']"
    assert_select "li", text: /Rowan Recipient.*No email or phone, can't be invited/
    assert_select "button[disabled]", "Invite"

    get team_project_path(project), params: { query: "Vic" }

    assert_response :success
    assert_select "section[aria-labelledby='members-heading'] li", text: /Vic Volunteer/, count: 1
    assert_select "section[aria-labelledby='directory-heading'] li", text: /Vic Volunteer/, count: 0
  end


  test "a Leader invites a Person as a Volunteer and Flockwork emails the invitation" do
    inviter = sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)

    get team_project_path(project), params: { query: "Vera" }
    assert_select "form[action='#{project_invitations_path(project)}']" do
      assert_select "input[name='invitation[person_id]'][value='#{invitee.id}']"
      assert_select "select[name='invitation[role]'] option[value='leader']", "Leader"
      assert_select "select[name='invitation[role]'] option[value='volunteer'][selected]", "Volunteer"
      assert_select "input[type='submit'][value='Invite']"
    end

    assert_difference "Invitation.count", 1 do
      assert_emails 1 do
        perform_enqueued_jobs do
          post project_invitations_path(project), params: {
            invitation: { person_id: invitee.id, role: "volunteer" }
          }
        end
      end
    end

    invitation = inviter.organization.invitations.find_by!(project: project, person: invitee)
    assert_redirected_to team_project_path(project)
    assert_equal inviter, invitation.inviter
    assert_predicate invitation, :volunteer?
    assert_predicate invitation, :pending?
    assert_nil invitation.responded_at

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "vera@st-example.test" ], mail.to
    assert_equal "You're invited to help with Community Meal on Flockwork", mail.subject
    assert_match %r{http://example.com/invitations/\S+}, mail.body.encoded
    invitation_token = mail.body.encoded[%r{/invitations/(\S+)}, 1]
    assert_equal invitation, Invitation.find_by_token_for(:access, invitation_token)
  end


  test "a signed-in invitee sees Accept and Decline actions" do
    sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)
    perform_enqueued_jobs do
      post project_invitations_path(project), params: {
        invitation: { person_id: invitee.id, role: "volunteer" }
      }
    end
    token = ActionMailer::Base.deliveries.last.body.encoded[%r{/invitations/(\S+)}, 1]
    delete session_path
    sign_in_as(invitee)

    get invitation_path(token)

    assert_response :success
    assert_select "h1", "Community Meal"
    assert_select "p", text: /Leo Leader invited you to join this Team as a Volunteer/
    assert_select "form[action='#{accept_invitation_path(token)}'] button", "Accept"
    assert_select "form[action='#{decline_invitation_path(token)}'] button", "Decline"

    get home_path

    assert_response :success
    assert_select "[data-signed-in-as]", "Vera Volunteer"
    assert_select "a", text: "Switch Church", count: 0
  end


  test "GET to an Invitation link does not switch an already signed-in browser to the invitee" do
    sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)
    perform_enqueued_jobs do
      post project_invitations_path(project), params: {
        invitation: { person_id: invitee.id, role: "volunteer" }
      }
    end
    token = ActionMailer::Base.deliveries.last.body.encoded[%r{/invitations/(\S+)}, 1]

    assert_emails 1 do
      perform_enqueued_jobs do
        get invitation_path(token)
      end
    end
    assert_response :success
    assert_select "h1", "Check your inbox"
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "vera@st-example.test" ], mail.to
    assert_equal "Your Flockwork sign-in link", mail.subject
    sign_in_token = mail.body.encoded[%r{/sign_in/(\S+)}, 1]
    assert_equal invitee, Person.find_by_token_for(:sign_in, sign_in_token)

    get home_path

    assert_response :success
    assert_select "[data-signed-in-as]", "Leo Leader"
  end


  test "an Invitation link sends at most three sign-in emails in fifteen minutes" do
    sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)
    perform_enqueued_jobs do
      post project_invitations_path(project), params: {
        invitation: { person_id: invitee.id, role: "volunteer" }
      }
    end
    invitation = invitee.invitations.find_by!(project: project)
    token = invitation.generate_token_for(:access)
    delete session_path
    ActionMailer::Base.deliveries.clear

    with_invitation_rate_limit_store do
      perform_enqueued_jobs do
        4.times { get invitation_path(token) }
      end
    end

    assert_response :success
    assert_select "h1", "Check your inbox"
    assert_equal 3, ActionMailer::Base.deliveries.count
  end


  test "a phone-only invitee receives a sign-in text and can sign in" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    invitee = leader.organization.people.create!(name: "Parker Phone", phone: "+15005550000")

    get team_project_path(project), params: { query: "Parker" }
    assert_select "form[action='#{project_invitations_path(project)}']" do
      assert_select "input[name='invitation[person_id]'][value='#{invitee.id}']"
      assert_select "input[type='submit'][value='Invite']"
    end

    assert_difference "Invitation.count", 1 do
      assert_no_emails do
        perform_enqueued_jobs do
          post project_invitations_path(project), params: {
            invitation: { person_id: invitee.id, role: "volunteer" }
          }
        end
      end
    end
    invitation = leader.organization.invitations.find_by!(project: project, person: invitee)
    token = invitation.generate_token_for(:access)
    delete session_path

    deliveries = []
    sendly = Messaging::Sendly.new(api_key: "test")
    send_sms = ->(**message) {
      deliveries << message
      { "id" => "msg_invitation", "status" => "queued", "simulated" => true }
    }
    stub_method(sendly, :send_sms, send_sms) do
      stub_method(Messaging::Sendly, :new, -> { sendly }) do
        assert_no_emails do
          perform_enqueued_jobs do
            get invitation_path(token)
          end
        end
      end
    end

    assert_response :success
    assert_select "h1", "Check your texts"
    assert_equal 1, deliveries.count
    assert_equal "+15005550000", deliveries.first.fetch(:to)
    assert_match %r{http://example\.com/sign_in/\S+}, deliveries.first.fetch(:text)
    sign_in_token = deliveries.first.fetch(:text)[%r{/sign_in/(\S+)}, 1]
    assert_equal invitee, Person.find_by_token_for(:sign_in, sign_in_token)

    get sign_in_link_path(sign_in_token)
    assert_select "h1", "Finish signing in"
    post sign_in_link_path(sign_in_token)
    assert_redirected_to home_path
    get home_path
    assert_select "[data-signed-in-as]", "Parker Phone"
  end


  test "an invitee without email or phone is told to contact the leader" do
    sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)
    perform_enqueued_jobs do
      post project_invitations_path(project), params: {
        invitation: { person_id: invitee.id, role: "volunteer" }
      }
    end
    invitation = invitee.invitations.find_by!(project: project)
    token = invitation.generate_token_for(:access)
    invitee.update!(email: nil, phone: nil)
    delete session_path
    ActionMailer::Base.deliveries.clear

    assert_no_enqueued_jobs do
      get invitation_path(token)
    end

    assert_response :success
    assert_select "h1", "Contact your leader"
    assert_select "p", "Ask your leader to add an email address or phone number before you respond to this Invitation."
    assert_empty ActionMailer::Base.deliveries
  end


  test "a copied pending Invitation link does not sign a Leader in as the invitee" do
    sign_in_as_leader
    project = projects(:community_meal)
    post project_invitations_path(project), params: {
      invitation: { person_id: people(:other_volunteer).id, role: "volunteer" }
    }
    get team_project_path(project)
    copy_button = css_select("button[data-controller='clipboard']").find do |button|
      button["data-clipboard-text-value"].include?("/invitations/")
    end
    assert copy_button
    copied_link = copy_button["data-clipboard-text-value"]
    assert_match %r{\Ahttp://www\.example\.com/invitations/\S+\z}, copied_link
    copied_token = copied_link[%r{/invitations/(\S+)}, 1]
    invitation = people(:other_volunteer).invitations.find_by!(project: project)
    assert_equal invitation, Invitation.find_by_token_for(:access, copied_token)

    reset!
    perform_enqueued_jobs do
      get copied_link
    end

    assert_response :success
    assert_select "h1", "Check your inbox"
    get home_path
    assert_redirected_to root_path
  end


  test "an Invitation link older than 14 days is refused" do
    leader = sign_in_as_leader
    project = projects(:community_meal)
    post project_invitations_path(project), params: {
      invitation: { person_id: people(:other_volunteer).id, role: "volunteer" }
    }
    invitation = leader.organization.invitations.find_by!(project: project, person: people(:other_volunteer))
    token = invitation.generate_token_for(:access)
    delete session_path

    travel 15.days do
      get invitation_path(token)
      assert_response :unprocessable_content
      assert_select "h1", "Invitation link not valid"
    end

    get home_path
    assert_redirected_to root_path
  end


  test "an invitee accepts from the emailed Invitation through a magic link" do
    memberships(:community_meal_other_leader).destroy!
    sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_leader)
    perform_enqueued_jobs do
      post project_invitations_path(project), params: {
        invitation: { person_id: invitee.id, role: "leader" }
      }
    end
    invitation = invitee.invitations.find_by!(project: project)
    token = ActionMailer::Base.deliveries.last.body.encoded[%r{/invitations/(\S+)}, 1]
    delete session_path
    perform_enqueued_jobs do
      get invitation_path(token)
    end
    assert_response :success
    assert_select "h1", "Check your inbox"
    assert_equal [ "lucy@st-example.test" ], ActionMailer::Base.deliveries.last.to
    assert_equal "Your Flockwork sign-in link", ActionMailer::Base.deliveries.last.subject

    sign_in_token = ActionMailer::Base.deliveries.last.body.encoded[%r{/sign_in/(\S+)}, 1]
    assert_equal invitee, Person.find_by_token_for(:sign_in, sign_in_token)
    get sign_in_link_path(sign_in_token)
    assert_select "h1", "Finish signing in"
    post sign_in_link_path(sign_in_token)
    assert_redirected_to home_path
    get invitation_path(token)

    assert_no_difference "Invitation.count" do
      assert_difference "Membership.count", 1 do
        patch accept_invitation_path(token)
      end
    end

    assert_redirected_to team_project_path(project)
    membership = project.memberships.find_by!(person: invitee)
    assert_predicate membership, :leader?
    assert_predicate invitation.reload, :accepted?
    assert_not_nil invitation.responded_at

    delete session_path
    get invitation_path(token)
    assert_response :unprocessable_content
    get home_path
    assert_redirected_to root_path
  end


  test "declining an Invitation creates no Membership and preserves the Invitation" do
    sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)
    perform_enqueued_jobs do
      post project_invitations_path(project), params: {
        invitation: { person_id: invitee.id, role: "volunteer" }
      }
    end
    invitation = invitee.invitations.find_by!(project: project)
    token = ActionMailer::Base.deliveries.last.body.encoded[%r{/invitations/(\S+)}, 1]
    delete session_path
    sign_in_as(invitee)
    get invitation_path(token)

    assert_no_difference [ "Invitation.count", "Membership.count" ] do
      patch decline_invitation_path(token)
    end

    assert_redirected_to home_path
    assert_predicate invitation.reload, :declined?
    assert_not_nil invitation.responded_at
    assert_nil project.memberships.find_by(person: invitee)
  end


  test "a Leader sees Invitation statuses with copy and text links for pending Invitations" do
    memberships(:community_meal_other_leader).destroy!
    leader = sign_in_as_leader
    project = projects(:community_meal)

    post project_invitations_path(project), params: {
      invitation: { person_id: people(:other_volunteer).id, role: "volunteer" }
    }
    pending_invitation = leader.organization.invitations.find_by!(project: project, person: people(:other_volunteer))

    post project_invitations_path(project), params: {
      invitation: { person_id: people(:other_leader).id, role: "leader" }
    }
    accepted_invitation = leader.organization.invitations.find_by!(project: project, person: people(:other_leader))
    accepted_token = accepted_invitation.generate_token_for(:access)
    delete session_path
    sign_in_as(people(:other_leader))
    get invitation_path(accepted_token)
    patch accept_invitation_path(accepted_token)

    delete session_path
    sign_in_as_leader
    post project_invitations_path(project), params: {
      invitation: { person_id: people(:admin).id, role: "volunteer" }
    }
    declined_invitation = leader.organization.invitations.find_by!(project: project, person: people(:admin))
    declined_token = declined_invitation.generate_token_for(:access)
    delete session_path
    sign_in_as(people(:admin))
    get invitation_path(declined_token)
    patch decline_invitation_path(declined_token)

    delete session_path
    sign_in_as_leader
    get team_project_path(project)

    assert_response :success
    assert_select "li", text: /Vera Volunteer.*Volunteer.*Pending/
    assert_select "li", text: /Lucy Leader.*Leader.*Accepted/
    assert_select "li", text: /Ada Admin.*Volunteer.*Declined/

    copy_button = css_select("button[data-controller='clipboard']").find do |button|
      button["data-clipboard-text-value"].include?("/invitations/")
    end
    assert copy_button
    pending_url = copy_button["data-clipboard-text-value"]
    pending_token = pending_url[%r{/invitations/(\S+)}, 1]
    assert_equal pending_invitation, Invitation.find_by_token_for(:access, pending_token)
    sms_body = ERB::Util.url_encode("You're invited to help with Community Meal on Flockwork: #{pending_url}")
    assert_select "button[data-controller='clipboard'][data-clipboard-text-value=?]", pending_url, text: "Copy Link"
    assert_select "a[href=?]", "sms:?&body=#{sms_body}", text: "Send by Text"
    assert_select "li", text: /Lucy Leader.*Accepted/ do
      assert_select "button[data-controller='clipboard']", count: 0
      assert_select "a[href^='sms:']", count: 0
    end
  end


  test "a Volunteer cannot invite and sees no invitation controls" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    get team_project_path(project), params: { query: "Vera" }

    assert_response :success
    assert_select "section[aria-labelledby='directory-heading']", count: 0
    assert_select "section[aria-labelledby='invitations-heading']", count: 0

    assert_no_difference "Invitation.count" do
      post project_invitations_path(project), params: {
        invitation: { person_id: people(:other_volunteer).id, role: "volunteer" }
      }
    end

    assert_response :not_found
  end

  test "a Person without email or phone and a Person with a pending Invitation cannot be invited" do
    leader = sign_in_as_leader
    project = projects(:community_meal)

    assert_no_difference "Invitation.count" do
      assert_no_emails do
        post project_invitations_path(project), params: {
          invitation: { person_id: people(:recipient).id, role: "volunteer" }
        }
      end
    end
    assert_redirected_to team_project_path(project, query: "Rowan Recipient")

    post project_invitations_path(project), params: {
      invitation: { person_id: people(:other_volunteer).id, role: "volunteer" }
    }
    assert_equal 1, leader.organization.invitations.pending.where(project: project, person: people(:other_volunteer)).count

    assert_no_difference "Invitation.count" do
      post project_invitations_path(project), params: {
        invitation: { person_id: people(:other_volunteer).id, role: "leader" }
      }
    end
    assert_equal 1, leader.organization.invitations.pending.where(project: project, person: people(:other_volunteer)).count
  end


  test "an invitee sees pending Invitations on the Organization home" do
    sign_in_as_leader
    project = projects(:community_meal)
    invitee = people(:other_volunteer)
    post project_invitations_path(project), params: {
      invitation: { person_id: invitee.id, role: "volunteer" }
    }
    delete session_path
    sign_in_as(invitee)
    get home_path

    assert_response :success
    assert_select "h2", "Pending Invitations"
    invitation_links = css_select("a[href^='/invitations/']")
    assert_equal 1, invitation_links.count
    invitation_link = invitation_links.first
    assert_match(/Community Meal.*Volunteer/m, invitation_link.text)
    token = invitation_link["href"][%r{/invitations/(\S+)}, 1]
    invitation = invitee.invitations.find_by!(project: project)
    assert_equal invitation, Invitation.find_by_token_for(:access, token)
  end


  test "a member leaves a Team" do
    member = sign_in_as_volunteer
    project = projects(:community_meal)
    membership = project.memberships.find_by!(person: member)

    assert_difference "Membership.count", -1 do
      delete project_membership_path(project, membership)
    end

    assert_redirected_to projects_path
    assert_nil project.memberships.find_by(person: member)
  end


  test "a Leader removes another member" do
    sign_in_as_leader
    project = projects(:community_meal)
    membership = project.memberships.find_by!(person: people(:volunteer))

    assert_difference "Membership.count", -1 do
      delete project_membership_path(project, membership)
    end

    assert_redirected_to team_project_path(project)
    assert_nil project.memberships.find_by(person: people(:volunteer))
  end

  test "the Owner cannot leave or be removed" do
    project = projects(:community_meal)
    owner_membership = project.memberships.find_by!(person: project.owner)
    sign_in_as_leader

    assert_no_difference "Membership.count" do
      delete project_membership_path(project, owner_membership)
    end
    assert_response :not_found

    delete session_path
    sign_in_as_admin

    assert_no_difference "Membership.count" do
      delete project_membership_path(project, owner_membership)
    end
    assert_response :not_found
    assert project.memberships.exists?(owner_membership.id)
  end

  test "a Project links to its Team" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    get project_path(project)

    assert_response :success
    assert_select "a.tab-link[href='#{team_project_path(project)}']", "Team"
  end

  private
    def with_invitation_rate_limit_store
      store = ActiveSupport::Cache::MemoryStore.new
      increment = ->(*args, **kwargs) { store.increment(*args, **kwargs) }
      stub_method(InvitationsController.cache_store, :increment, increment) { yield }
    end
end
