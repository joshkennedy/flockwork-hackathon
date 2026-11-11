require "test_helper"

class CsvImportTest < ActionDispatch::IntegrationTest
  test "Admin imports a CSV and creates new People" do
    sign_in_as_admin
    organization = organizations(:st_example)
    starting_count = organization.people.count

    upload_csv "people_import.csv"

    assert_response :success
    assert_select "p", text: /2 created, 1 updated, 0 rejected/

    assert_equal starting_count + 2, organization.people.reload.count
    assert organization.people.exists?(name: "New Person", email: "np@st-example.test", phone: "555-1001")
    assert organization.people.exists?(name: "No Email Person", email: nil)
  end

  test "matching email updates instead of duplicating" do
    sign_in_as_admin
    organization = organizations(:st_example)
    starting_count = organization.people.count

    upload_csv "people_import.csv"

    assert_equal starting_count + 2, organization.people.reload.count
    people(:leader).reload
    assert_equal "Updated Leader", people(:leader).name
    assert_equal "555-2002", people(:leader).phone
  end

  test "re-import preserves an existing phone when the CSV omits or blanks it" do
    sign_in_as_admin
    person = organizations(:st_example).people.create!(name: "Phone Person", email: "phone-person@st-example.test", phone: "555-4004")

    upload_csv_bytes "name,email\nNo Phone Column,#{person.email}\n"
    assert_equal "555-4004", person.reload.phone

    upload_csv_bytes "name,email,phone\nBlank Phone,#{person.email},\n"
    assert_equal "555-4004", person.reload.phone
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
    organization = organizations(:st_example)

    assert_no_difference -> { organization.people.count } do
      upload_csv "people_import_malformed.csv"
    end

    assert_response :unprocessable_entity
    assert_select "[data-toast-entry][data-toast-kind=alert]", text: "That file isn't a CSV with a name column."

    assert_no_difference -> { organization.people.count } do
      upload_csv "people_import_no_name_column.csv"
    end

    assert_response :unprocessable_entity
    assert_select "[data-toast-entry][data-toast-kind=alert]", text: "That file isn't a CSV with a name column."
  end

  test "UTF-8 BOM does not break the name column" do
    sign_in_as_admin
    organization = organizations(:st_example)

    upload_csv_bytes "\xEF\xBB\xBFname,email,phone\nBOM Person,bom@st-example.test,555-3003\n"

    assert_response :success
    assert_select "p", text: /1 created, 0 updated, 0 rejected/
    assert organization.people.exists?(name: "BOM Person", email: "bom@st-example.test", phone: "555-3003")
  end

  test "oversized CSV is refused and changes nothing" do
    sign_in_as_admin
    organization = organizations(:st_example)

    assert_no_difference -> { organization.people.count } do
      upload_csv_bytes "name,email\n#{'x' * 1.megabyte},too-big@st-example.test\n"
    end

    assert_response :unprocessable_entity
    assert_select "[data-toast-entry][data-toast-kind=alert]", text: CsvImport::TOO_LARGE_MESSAGE
    assert_not organization.people.exists?(email: "too-big@st-example.test")
  end

  test "a CSV with too many rows is refused and changes nothing" do
    sign_in_as_admin
    organization = organizations(:st_example)
    rows = (1..5_001).map { |n| "Person #{n},p#{n}@st-example.test\n" }.join

    assert_no_difference -> { organization.people.count } do
      upload_csv_bytes "name,email\n#{rows}"
    end

    assert_response :unprocessable_entity
    assert_select "[data-toast-entry][data-toast-kind=alert]", text: CsvImport::TOO_LARGE_MESSAGE
    assert_not organization.people.exists?(email: "p1@st-example.test")
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

    def upload_csv_bytes(contents)
      file = Tempfile.new([ "people-import", ".csv" ], binmode: true)
      file.write(contents)
      file.rewind
      post people_csv_import_path, params: {
        csv_file: Rack::Test::UploadedFile.new(file.path, "text/csv")
      }
    ensure
      file.close!
    end
end
