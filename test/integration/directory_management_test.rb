require "test_helper"

class DirectoryManagementTest < ActionDispatch::IntegrationTest
  test "Admin adds a Person with email and they appear in the directory" do
    sign_in_as_admin

    assert_difference -> { organizations(:st_example).people.count }, 1 do
      post people_path, params: {
        person: { name: "Pat Person", email: "pat@st-example.test", phone: "555-0100" }
      }
    end

    assert_redirected_to people_path
    follow_redirect!
    assert_select "li", /Pat Person/
    assert_select "li", /pat@st-example\.test/
  end

  test "Admin adds a Person without email; they show as unable to sign in and cannot receive a link" do
    sign_in_as_admin

    post people_path, params: { person: { name: "No Email Pat" } }

    assert_redirected_to people_path
    person = organizations(:st_example).people.find_by!(name: "No Email Pat")
    assert_not person.can_sign_in?

    follow_redirect!
    assert_select "li", /No Email Pat/
    assert_select "li", /Can't sign in/

    delete session_path
    assert_no_emails do
      perform_enqueued_jobs do
        post sign_in_requests_path, params: { email: "pat@st-example.test" }
      end
    end
  end

  test "saving from the Edit details slideout refreshes the person page" do
    sign_in_as_admin

    patch person_path(people(:volunteer)), params: { person: { name: "Victor Volunteer" } }, headers: { "Turbo-Frame" => "edit-person" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, %(<turbo-stream action="refresh">)
    assert_equal "Victor Volunteer", people(:volunteer).reload.name
  end

  test "Admin edits another Person's name, email and phone" do
    sign_in_as_admin

    patch person_path(people(:volunteer)), params: {
      person: { name: "Victor Volunteer", email: "victor@st-example.test", phone: "555-0199", admin: "0" }
    }

    assert_redirected_to person_path(people(:volunteer))
    people(:volunteer).reload
    assert_equal "Victor Volunteer", people(:volunteer).name
    assert_equal "victor@st-example.test", people(:volunteer).email
    assert_equal "555-0199", people(:volunteer).phone
  end

  test "Admin grants and revokes Admin on another Person" do
    sign_in_as_admin

    patch person_path(people(:leader)), params: {
      person: { name: people(:leader).name, email: people(:leader).email, admin: "1" }
    }

    assert people(:leader).reload.admin?

    patch person_path(people(:leader)), params: {
      person: { name: people(:leader).name, email: people(:leader).email, admin: "0" }
    }

    assert_not people(:leader).reload.admin?
  end

  test "the last Admin cannot revoke their own Admin role" do
    sign_in_as_admin

    patch person_path(people(:admin)), params: {
      person: { name: people(:admin).name, email: people(:admin).email, admin: "0" }
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Admin cannot be removed from the last Admin in the Organization/
    assert people(:admin).reload.admin?
  end

  test "non-Admin gets 404 on directory management" do
    sign_in_as_volunteer

    get people_path
    assert_response :not_found

    get new_person_path
    assert_response :not_found

    post people_path, params: { person: { name: "Sneak" } }
    assert_response :not_found

    get edit_person_path(people(:leader))
    assert_response :not_found
  end

  test "a Person edits their own name and phone" do
    sign_in_as_volunteer

    patch profile_path, params: {
      person: { name: "Vic Updated", phone: "555-7777" }
    }

    assert_redirected_to home_path
    people(:volunteer).reload
    assert_equal "Vic Updated", people(:volunteer).name
    assert_equal "555-7777", people(:volunteer).phone
  end

  test "forged admin param on profile update does not grant Admin" do
    sign_in_as_volunteer

    patch profile_path, params: {
      person: { name: people(:volunteer).name, phone: "", admin: "1", email: "hacker@example.com" }
    }

    assert_redirected_to home_path
    people(:volunteer).reload
    assert_not people(:volunteer).admin?
    assert_equal "vic@st-example.test", people(:volunteer).email
  end

  test "duplicate email in the same Organization is rejected on the form" do
    sign_in_as_admin

    post people_path, params: {
      person: { name: "Duplicate", email: people(:leader).email }
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Email has already been taken/
  end

  test "the same email in another Organization is allowed" do
    sign_in_as_outsider

    assert_difference -> { organizations(:outsider_church).people.count }, 1 do
      post people_path, params: {
        person: { name: "Shared Email", email: people(:admin).email }
      }
    end

    assert_redirected_to people_path
  end

  test "organization home links to People for Admins and to My profile for everyone" do
    sign_in_as_admin
    get home_path
    assert_select "a[href=?]", people_path, text: "People"
    assert_select "a[href=?]", edit_profile_path

    delete session_path
    sign_in_as_volunteer
    get home_path
    assert_select "a[href=?]", people_path, count: 0
    assert_select "a[href=?]", edit_profile_path
  end

  test "the directory lists People sorted by name" do
    sign_in_as_admin

    get people_path

    assert_response :success
    names = css_select("turbo-frame#people-results li a.font-semibold").map { |link| link.text.strip }
    assert_equal names.sort, names
  end

  test "each directory row links the Person's name to their person page" do
    sign_in_as_admin

    get people_path

    assert_select "a[href=?]", person_path(people(:volunteer)), text: people(:volunteer).name
    assert_select "a", text: "Edit", count: 0
  end

  test "searching the directory by name narrows the list" do
    sign_in_as_admin

    get people_path, params: { query: "vic" }

    assert_response :success
    assert_select "turbo-frame#people-results a", text: people(:volunteer).name
    assert_select "turbo-frame#people-results a", text: people(:leader).name, count: 0
  end

  test "a search with no match says so and offers to clear it" do
    sign_in_as_admin

    get people_path, params: { query: "zzz no such person" }

    assert_select "turbo-frame#people-results p", text: /No people match "zzz no such person"/
    assert_select "turbo-frame#people-results a[href=?]", people_path, text: "Clear search"
  end

  test "the CSV file input has a visible label" do
    sign_in_as_admin

    get new_people_csv_import_path

    assert_select "label[for=?]", "csv_file", text: "CSV file"
    assert_select "input#csv_file[type=file]"
  end

  test "the Admin checkbox says what Admins can do" do
    sign_in_as_admin

    get edit_person_path(people(:leader))

    assert_select "p", text: "Admins can manage People and Settings."
  end
end
