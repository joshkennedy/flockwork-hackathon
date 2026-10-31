require "test_helper"

class CsvImportTest < ActionDispatch::IntegrationTest
  test "Admin imports a CSV and creates new People" do
    sign_in_as_admin
    workspace = workspaces(:st_example)
    starting_count = workspace.people.count

    upload_csv "people_import.csv"

    assert_response :success
    assert_select "p", text: /2 created, 1 updated, 0 rejected/

    assert_equal starting_count + 2, workspace.people.reload.count
    assert workspace.people.exists?(name: "New Person", email: "np@st-example.test", phone: "555-1001")
    assert workspace.people.exists?(name: "No Email Person", email: nil)
  end

  test "matching email updates instead of duplicating" do
    sign_in_as_admin
    workspace = workspaces(:st_example)
    starting_count = workspace.people.count

    upload_csv "people_import.csv"

    assert_equal starting_count + 2, workspace.people.reload.count
    people(:leader).reload
    assert_equal "Updated Leader", people(:leader).name
    assert_equal "555-2002", people(:leader).phone
  end

  test "rejected rows show line numbers and reasons" do
    sign_in_as_admin

    upload_csv "people_import_rejected.csv"

    assert_response :success
    assert_select "p", text: /1 created, 0 updated, 3 rejected/
    assert_select "td", text: "2"
    assert_select "td", text: "Name is missing"
    assert_select "td", text: "3"
    assert_select "td", text: /Email is invalid/
    assert_select "td", text: "5"
    assert_select "td", text: "Name is missing"
  end

  test "malformed file is refused and changes nothing" do
    sign_in_as_admin
    workspace = workspaces(:st_example)

    assert_no_difference -> { workspace.people.count } do
      upload_csv "people_import_malformed.csv"
    end

    assert_response :unprocessable_entity
    assert_select "p[role=alert]", text: "That file isn't a CSV with a name column."

    assert_no_difference -> { workspace.people.count } do
      upload_csv "people_import_no_name_column.csv"
    end

    assert_response :unprocessable_entity
    assert_select "p[role=alert]", text: "That file isn't a CSV with a name column."
  end

  test "non-Admin gets 404 on CSV import" do
    sign_in_as_volunteer

    get new_people_csv_import_path
    assert_response :not_found

    upload_csv "people_import.csv"
    assert_response :not_found
  end

  private
    def upload_csv(filename)
      post people_csv_import_path, params: {
        csv_file: fixture_file_upload(filename, "text/csv")
      }
    end
end
