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

  test "the project keeps sharing and ownership visible" do
    sign_in_as_leader
    project = projects(:community_meal)

    get project_path(project)
    assert_select "section[data-project-settings] h2", text: /Sharing and ownership/
    assert_select "details.actions-menu form[action=?]", mark_done_project_path(project)

    post enable_public_link_project_path(project)
    get project_path(project)
    assert_select "section[data-project-settings] h2", text: /Public link on/
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

  test "turning the Public link off invalidates the old banner URL" do
    project = projects(:community_meal)
    attach_ready_banner(project)
    project.banner.blob.update!(metadata: project.banner.blob.metadata.except("organization_id"))
    project.enable_public_link!
    token = project.public_token
    old_banner_blob_id = project.banner.blob_id

    get public_project_path(token)
    banner_path = css_select("picture img").first["src"]

    get banner_path
    assert_response :redirect
    follow_redirect!
    assert_response :success

    project.disable_public_link!
    perform_enqueued_jobs

    assert_not_equal old_banner_blob_id, project.reload.banner.blob_id
    assert_equal project.organization_id, project.banner.blob.metadata["organization_id"]
    get public_project_path(token)
    assert_response :not_found

    get banner_path
    follow_redirect! if response.redirect?
    assert_response :not_found

    sign_in_as_leader
    get project_path(project)
    assert_select "picture img[alt=?]", "#{project.name} banner"
  end

  test "resetting the Public link invalidates the old banner URL and keeps the banner public" do
    project = projects(:community_meal)
    attach_ready_banner(project)
    project.enable_public_link!
    old_token = project.public_token
    old_banner_blob_id = project.banner.blob_id

    get public_project_path(old_token)
    old_banner_path = css_select("picture img").first["src"]

    project.reset_public_link!
    perform_enqueued_jobs

    assert_not_equal old_banner_blob_id, project.reload.banner.blob_id
    get old_banner_path
    follow_redirect! if response.redirect?
    assert_response :not_found

    get public_project_path(project.public_token)
    assert_select "picture img[alt=?]", "#{project.name} banner"
    assert_not_equal old_banner_path, css_select("picture img").first["src"]
  end

  test "deleting a Project invalidates its old public banner URL" do
    sign_in_as_admin
    project = projects(:community_meal)
    attach_ready_banner(project)
    project.enable_public_link!
    old_banner_blob_id = project.banner.blob_id

    get public_project_path(project.public_token)
    old_banner_path = css_select("picture img").first["src"]

    delete project_path(project)

    assert_not_equal old_banner_blob_id, project.reload.banner.blob_id
    get old_banner_path
    follow_redirect! if response.redirect?
    assert_response :not_found
    assert project.reload.banner.attached?
  end

  test "a failed Public link revocation keeps the current banner attachment" do
    project = projects(:community_meal)
    attach_ready_banner(project)
    project.enable_public_link!
    old_token = project.public_token
    old_banner_blob_id = project.banner.blob_id

    project.name = nil
    assert_raises(ActiveRecord::RecordInvalid) do
      project.disable_public_link!
    end

    project.reload
    assert_equal old_token, project.public_token
    assert_equal old_banner_blob_id, project.banner.blob_id
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
    slot = project.slots.create!(date: "2027-02-15", label: "Bring dessert", capacity: 3)
    slot.claim(volunteer)

    sign_in_as_leader
    post enable_public_link_project_path(project)
    token = project.reload.public_token
    delete session_path

    get public_project_path(token)
    assert_response :success
    assert_select "section[aria-labelledby='public-slots']", text: /Bring dessert/
    assert_select "section[aria-labelledby='public-slots']", text: /2 spots left/
    assert_no_match volunteer.name, response.body
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
