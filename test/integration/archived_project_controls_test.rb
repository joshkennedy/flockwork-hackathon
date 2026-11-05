require "test_helper"

class ArchivedProjectControlsTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @project.update!(enabled_tools: Project::TOOLS, open_team: true)
    populate(@project)
    @project.update!(archived_at: Time.current)
  end

  test "no write control renders on an archived Project for any role" do
    offenders = %i[admin leader other_leader volunteer].to_h do |role|
      sign_in_as(role)
      get project_path(@project)
      assert_response :success
      %w[Open\ task Hello\ team Run\ of\ show Bring\ dessert Greeter].each { |text| assert_includes response.body, text }
      [ role, write_controls ]
    end

    assert_equal({ admin: [], leader: [], other_leader: [], volunteer: [] }, offenders)
  end

  test "the Owner is told the Project is archived and can unarchive from the notice" do
    sign_in_as_leader
    get project_path(@project)

    assert_select "[data-archived-notice]", text: /archived/i
    assert_select "[data-archived-notice] form[action='#{unarchive_project_path(@project)}'] button", "Unarchive to edit"
  end

  test "an Admin who is not the Owner sees the notice without the unarchive button" do
    sign_in_as_admin
    get project_path(@project)

    assert_select "[data-archived-notice]", text: /archived/i
    assert_select "[data-archived-notice] form", false
    assert_select "button", text: /Unarchive/, count: 0
  end

  test "a Team member sees the notice without the unarchive button" do
    sign_in_as_volunteer
    get project_path(@project)

    assert_select "[data-archived-notice]", text: /archived/i
    assert_select "button", text: /Unarchive/, count: 0
  end

  test "the Owner and Admins cannot write until the Owner unarchives" do
    sign_in_as_leader
    assert_no_difference "Task.count" do
      post project_tasks_path(@project), params: { task: { title: "Owner task" } }
    end

    sign_in_as_admin
    assert_no_difference "Task.count" do
      post project_tasks_path(@project), params: { task: { title: "Admin task" } }
    end

    sign_in_as_leader
    post unarchive_project_path(@project)
    assert_nil @project.reload.archived_at
    assert_difference "Task.count", 1 do
      post project_tasks_path(@project), params: { task: { title: "Owner task" } }
    end
  end

  test "ownership cannot be transferred while the Project is archived" do
    sign_in_as_leader

    patch transfer_ownership_project_path(@project), params: { new_owner_id: people(:other_leader).id }

    assert_equal people(:leader), @project.reload.owner
  end

  test "an archived Project's invitation page offers Decline but not Accept" do
    @project.update!(archived_at: nil)
    invitee = people(:other_volunteer)
    invitation = @project.organization.invitations.create!(project: @project, person: invitee, inviter: people(:leader), role: "volunteer")
    token = invitation.generate_token_for(:access)
    sign_in_as(invitee)

    get invitation_path(token)
    assert_select "button", text: "Accept"

    @project.update!(archived_at: Time.current)
    get invitation_path(token)
    assert_response :success
    assert_select "button", text: "Accept", count: 0
    assert_select "button", text: "Decline"
  end

  test "saved debrief answers cannot be changed on a done and archived Project" do
    @project.update!(done_at: Time.current)
    debrief = @project.create_project_debrief!(what_worked: "Early setup", change_next_time: "More chairs")

    %i[leader admin other_leader].each do |role|
      sign_in_as(role)
      get project_path(@project)
      assert_select "a", text: "Project Debrief", count: 0

      get edit_project_debrief_path(@project)
      assert_response :not_found

      patch project_debrief_path(@project), params: { project_debrief: { what_worked: "Changed", change_next_time: "Changed" } }
      assert_response :not_found
    end

    assert_equal [ "Early setup", "More chairs" ], debrief.reload.attributes.values_at("what_worked", "change_next_time")
  end

  private
    def populate(project)
      leader = people(:leader)
      volunteer = people(:volunteer)
      project.tasks.create!(title: "Open task", assignee: volunteer)
      project.tasks.create!(title: "Unclaimed task")
      project.tasks.create!(title: "Done task", assignee: volunteer, completed_at: Time.current, completed_by: volunteer)
      slot = project.slots.create!(date: "2027-02-15", label: "Bring dessert", capacity: 2)
      slot.slot_claims.create!(person: volunteer)
      project.slots.create!(date: "2027-02-16", label: "Dinner", capacity: 1)
      item = project.schedule_items.create!(title: "Sunday service", date: "2027-02-17", starts_at_time: "09:00")
      project.slots.create!(date: "2027-02-17", label: "Greeter", capacity: 2, schedule_item: item)
      message = project.messages.create!(author: leader, body: "Hello team")
      message.comments.create!(author: volunteer, body: "Reply")
      project.doc_items.create!(kind: "document", title: "Run of show", body: "Plan", author: leader)
      project.doc_items.create!(kind: "link", title: "Map", url: "https://example.com", author: leader)
      project.recipients.create!(person: people(:other_volunteer))
      project.notes.create!(organization: project.organization, author: leader, visibility: "team", body: "Team note")
    end

    # Unfollowing is a personal setting and Deleting a Project is a restorable Admin lifecycle action; neither writes to a Tool.
    def allowed_form?(form)
      action = form["action"].to_s
      action.in?([ unarchive_project_path(@project), project_path(@project) ]) || action.include?("/follows/")
    end

    # Forms (other than Unarchive, Delete and the app chrome) and links to new/edit pages inside the page content.
    def write_controls
      main = css_select("main").first || css_select("body").first
      forms = main.css("form").reject { |form| allowed_form?(form) }
      claims = main.css("a").select { |a| a.text.strip == "Claim" }.map { |a| "link Claim #{a['href']}" }
      links = main.css("a[href]").select { |a| a["href"].match?(%r{/(new|edit)(\?|/|$)|/new\b}) && !a["href"].include?("/duplicate") }
      forms.map { |f| "#{f.at_css('input[name=_method]')&.[]('value') || f['method']} #{f['action']} #{f.css('button, input[type=submit]').map { |b| (b['value'] || b.text).strip }.join}" } + links.map { |a| "link #{a['href']}" } + claims
    end
end
