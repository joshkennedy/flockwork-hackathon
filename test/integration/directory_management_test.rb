require "test_helper"

class DirectoryManagementTest < ActionDispatch::IntegrationTest
  test "Admin adds a Person with email and they appear in the directory" do
    sign_in_as_admin

    assert_difference -> { workspaces(:st_example).people.count }, 1 do
      post people_path("st-example"), params: {
        person: { name: "Pat Person", email: "pat@st-example.test", phone: "555-0100" }
      }
    end

    assert_redirected_to people_path("st-example")
    follow_redirect!
    assert_select "li", /Pat Person/
    assert_select "li", /pat@st-example\.test/
  end

  test "Admin adds a Person without email; they show as unable to sign in and cannot receive a link" do
    sign_in_as_admin

    post people_path("st-example"), params: { person: { name: "No Email Pat" } }

    assert_redirected_to people_path("st-example")
    person = workspaces(:st_example).people.find_by!(name: "No Email Pat")
    assert_not person.can_sign_in?

    follow_redirect!
    assert_select "li", /No Email Pat/
    assert_select "li", /Can't sign in \(no email\)/

    delete session_path
    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path(workspaces(:st_example)), params: { email: "pat@st-example.test" }
      end
    end
  end

  test "Admin edits another Person's name, email and phone" do
    sign_in_as_admin

    patch person_path("st-example", people(:volunteer)), params: {
      person: { name: "Victor Volunteer", email: "victor@st-example.test", phone: "555-0199", admin: "0" }
    }

    assert_redirected_to people_path("st-example")
    people(:volunteer).reload
    assert_equal "Victor Volunteer", people(:volunteer).name
    assert_equal "victor@st-example.test", people(:volunteer).email
    assert_equal "555-0199", people(:volunteer).phone
  end

  test "Admin grants and revokes Admin on another Person" do
    sign_in_as_admin

    patch person_path("st-example", people(:leader)), params: {
      person: { name: people(:leader).name, email: people(:leader).email, admin: "1" }
    }

    assert people(:leader).reload.admin?

    patch person_path("st-example", people(:leader)), params: {
      person: { name: people(:leader).name, email: people(:leader).email, admin: "0" }
    }

    assert_not people(:leader).reload.admin?
  end

  test "the last Admin cannot revoke their own Admin role" do
    sign_in_as_admin

    patch person_path("st-example", people(:admin)), params: {
      person: { name: people(:admin).name, email: people(:admin).email, admin: "0" }
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Admin cannot be removed from the last Admin in the Workspace/
    assert people(:admin).reload.admin?
  end

  test "non-Admin gets 404 on directory management" do
    sign_in_as_volunteer

    get people_path("st-example")
    assert_response :not_found

    get new_person_path("st-example")
    assert_response :not_found

    post people_path("st-example"), params: { person: { name: "Sneak" } }
    assert_response :not_found

    get edit_person_path("st-example", people(:leader))
    assert_response :not_found
  end

  test "a Person edits their own name and phone" do
    sign_in_as_volunteer

    patch profile_path("st-example"), params: {
      person: { name: "Vic Updated", phone: "555-7777" }
    }

    assert_redirected_to workspace_path("st-example")
    people(:volunteer).reload
    assert_equal "Vic Updated", people(:volunteer).name
    assert_equal "555-7777", people(:volunteer).phone
  end

  test "forged admin param on profile update does not grant Admin" do
    sign_in_as_volunteer

    patch profile_path("st-example"), params: {
      person: { name: people(:volunteer).name, phone: "", admin: "1", email: "hacker@example.com" }
    }

    assert_redirected_to workspace_path("st-example")
    people(:volunteer).reload
    assert_not people(:volunteer).admin?
    assert_equal "vic@st-example.test", people(:volunteer).email
  end

  test "duplicate email in the same Workspace is rejected on the form" do
    sign_in_as_admin

    post people_path("st-example"), params: {
      person: { name: "Duplicate", email: people(:leader).email }
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Email has already been taken/
  end

  test "the same email in another Workspace is allowed" do
    sign_in_as_outsider

    assert_difference -> { workspaces(:outsider_church).people.count }, 1 do
      post people_path("outsider-church"), params: {
        person: { name: "Shared Email", email: people(:admin).email }
      }
    end

    assert_redirected_to people_path("outsider-church")
  end

  test "workspace home links to People for Admins and to My profile for everyone" do
    sign_in_as_admin
    get workspace_path("st-example")
    assert_select "a[href=?]", people_path("st-example"), text: "People"
    assert_select "a[href=?]", edit_profile_path("st-example"), text: "My profile"

    delete session_path
    sign_in_as_volunteer
    get workspace_path("st-example")
    assert_select "a[href=?]", people_path("st-example"), count: 0
    assert_select "a[href=?]", edit_profile_path("st-example"), text: "My profile"
  end

  test "the directory lists People sorted by name" do
    sign_in_as_admin

    get people_path("st-example")

    assert_response :success
    names = css_select("ul li").map do |li|
      li.at_css("p.font-medium").text.sub(/\s+Admin\z/, "").strip
    end
    assert_equal names.sort, names
  end
end
