require "test_helper"

class PlanningCenterDirectoryTest < ActionDispatch::IntegrationTest
  test "Admin connects Planning Center and sees the connected state" do
    sign_in_as_admin

    patch planning_center_directory_path, params: {
      organization: { pco_app_id: "cassette-app-id", pco_secret: "cassette-secret" }
    }

    assert_redirected_to planning_center_directory_path
    follow_redirect!
    assert_select "p", text: "Connected"
    assert organizations(:st_example).reload.planning_center_connected?
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

    assert_difference -> { organization.people.count }, 25 do
      sync_with_recording
    end

    existing.reload
    assert_equal "Ruth Bennett", existing.name
    assert_equal "ruth.bennett@grace.example", existing.email
    assert_equal "202-555-0104", existing.phone
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

  test "rejected credentials show a plain error and change no People" do
    sign_in_as_admin
    connect(app_id: "wrong", secret: "wrong")
    organization = organizations(:st_example)

    assert_no_difference -> { organization.people.count } do
      VCR.use_cassette("planning_center/unauthorized") do
        perform_enqueued_jobs { post sync_planning_center_directory_path }
      end
    end

    follow_redirect!
    assert_select "p", text: "Planning Center didn't accept those credentials."
  end

  test "non-Admin gets 404 on Planning Center connection" do
    sign_in_as_volunteer

    get planning_center_directory_path

    assert_response :not_found
  end

  test "People directory links to Planning Center" do
    sign_in_as_admin

    get people_path

    assert_select "a[href=?]", planning_center_directory_path, text: "Planning Center"
  end

  private
    def connect(app_id: "cassette-app-id", secret: "cassette-secret")
      patch planning_center_directory_path, params: {
        organization: { pco_app_id: app_id, pco_secret: secret }
      }
    end

    def sync_with_recording
      VCR.use_cassette("planning_center/people") do
        perform_enqueued_jobs { post sync_planning_center_directory_path }
      end
    end
end
