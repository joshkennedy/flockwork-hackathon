require "test_helper"
require "yaml"

class PublicLinkTest < ActionDispatch::IntegrationTest
  FIXTURE_PEOPLE_NAMES = YAML.load_file(Rails.root.join("test/fixtures/people.yml")).values.filter_map { |attrs| attrs["name"] }.freeze

  test "a Leader turns the Public link on and visitors see the public page" do
    sign_in_as_leader
    project = projects(:community_meal)

    assert_nil project.public_token

    post enable_public_link_project_path(project)
    assert_redirected_to project_path(project)

    project.reload
    assert project.public_token.present?

    get public_project_path(project.public_token)
    assert_response :success
    assert_select "h1", "Community Meal"
    assert_select "meta[name=robots][content=noindex]", count: 1
  end

  test "resetting the Public link invalidates the old URL" do
    sign_in_as_leader
    project = projects(:community_meal)
    post enable_public_link_project_path(project)
    old_token = project.reload.public_token

    post reset_public_link_project_path(project)
    assert_redirected_to project_path(project)

    project.reload
    assert_not_equal old_token, project.public_token

    get public_project_path(old_token)
    assert_response :not_found

    get public_project_path(project.public_token)
    assert_response :success
  end

  test "turning the Public link off responds as not found" do
    sign_in_as_leader
    project = projects(:community_meal)
    post enable_public_link_project_path(project)
    token = project.reload.public_token

    post disable_public_link_project_path(project)
    assert_redirected_to project_path(project)
    assert_nil project.reload.public_token

    get public_project_path(token)
    assert_response :not_found
  end

  test "the public view shows allowed content and no Person names" do
    sign_in_as_leader
    project = projects(:community_meal)
    volunteer = people(:volunteer)

    open_task = project.tasks.create!(title: "Public Open Task", due_on: "2027-02-11")
    assigned_task = project.tasks.create!(title: "Hidden Assigned Task", assignee: volunteer)
    project.tasks.create!(title: "Hidden Done Task", completed_at: Time.current)

    project.update!(enabled_tools: project.enabled_tools + [ "signup_sheet" ])
    slot = project.slots.create!(date: "2027-02-15", starts_at_time: "18:30", label: "Serve dinner", capacity: 3)
    project.slots.create!(date: "2027-02-16", label: "Full slot", capacity: 1).tap do |full|
      full.claim(volunteer)
    end

    post enable_public_link_project_path(project)
    token = project.reload.public_token

    get public_project_path(token)
    assert_response :success

    assert_select "h1", "Community Meal"
    assert_match "Prepare and serve a neighborhood dinner.", response.body
    assert_match "February 12, 2027", response.body

    assert_select "section[aria-labelledby='public-schedule']", text: /Arrival/
    assert_select "section[aria-labelledby='public-schedule']", text: /Opening Session/
    assert_select "section[aria-labelledby='public-schedule']", text: /Lunch/
    assert_select "section[aria-labelledby='public-schedule']", text: /Fellowship Hall/

    assert_select "section[aria-labelledby='public-tasks']", text: /Public Open Task/
    assert_select "section[aria-labelledby='public-tasks']", text: /Due February 11, 2027/
    assert_select "section[aria-labelledby='public-tasks']", text: /Hidden Assigned Task/, count: 0
    assert_select "section[aria-labelledby='public-tasks']", text: /Hidden Done Task/, count: 0

    assert_select "section[aria-labelledby='public-slots']", text: /Serve dinner/
    assert_select "section[aria-labelledby='public-slots']", text: /3 spots left/
    assert_select "section[aria-labelledby='public-slots']", text: /Full slot/, count: 0

    FIXTURE_PEOPLE_NAMES.each do |name|
      assert_no_match Regexp.escape(name), response.body, "public page must not include #{name}"
    end
  end

  test "a claimed Slot shows fewer spots without the claimer's name" do
    volunteer = sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "signup_sheet" ])
    slot = project.slots.create!(date: "2027-02-15", label: "Bring dessert", capacity: 2)
    slot.claim(volunteer)

    sign_in_as_leader
    post enable_public_link_project_path(project)
    token = project.reload.public_token

    get public_project_path(token)
    assert_response :success
    assert_select "section[aria-labelledby='public-slots']", text: /Bring dessert/
    assert_select "section[aria-labelledby='public-slots']", text: /1 spot left/
    assert_no_match volunteer.name, response.body
  end

  test "Sign in to help links point to the Organization sign-in page" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "signup_sheet" ])
    project.tasks.create!(title: "Help with setup")
    slot = project.slots.create!(date: "2027-02-15", label: "Setup crew", capacity: 2)

    post enable_public_link_project_path(project)
    token = project.reload.public_token
    sign_in_path = new_sign_in_request_path

    get public_project_path(token)
    assert_response :success

    assert_select "section[aria-labelledby='public-tasks'] a[href=?]", sign_in_path, text: "Sign in to help"
    assert_select "section[aria-labelledby='public-slots'] a[href=?]", sign_in_path, text: "Sign in to help"
  end

  test "a Volunteer cannot toggle the Public link" do
    sign_in_as_leader
    project = projects(:community_meal)
    post enable_public_link_project_path(project)

    sign_in_as_volunteer

    post enable_public_link_project_path(project)
    assert_response :not_found

    post reset_public_link_project_path(project)
    assert_response :not_found

    post disable_public_link_project_path(project)
    assert_response :not_found
  end

  test "archived and deleted Projects respond as not found on the public page" do
    sign_in_as_leader
    project = projects(:community_meal)
    post enable_public_link_project_path(project)
    token = project.reload.public_token

    project.update!(archived_at: Time.current)
    get public_project_path(token)
    assert_response :not_found

    project.update!(archived_at: nil, deleted_at: Time.current)
    get public_project_path(token)
    assert_response :not_found
  end

  test "an unknown Public link token responds as not found" do
    get public_project_path("not-a-real-token")
    assert_response :not_found
  end

  test "the Project page shows the copyable Public URL when the link is on" do
    sign_in_as_leader
    project = projects(:community_meal)

    post enable_public_link_project_path(project)
    token = project.reload.public_token

    get project_path(project)
    assert_response :success
    assert_select "input[readonly][value=?]", public_project_url(token)
    assert_select "form[action=?]", enable_public_link_project_path(project), count: 0
    assert_select "form[action=?]", reset_public_link_project_path(project)
    assert_select "form[action=?]", disable_public_link_project_path(project)
  end
end
