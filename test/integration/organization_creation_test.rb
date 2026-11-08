require "test_helper"

class OrganizationCreationTest < ActionDispatch::IntegrationTest
  test "creating an Organization makes the creator its Admin, signs them in, and lands on New Project" do
    post organizations_path, params: { church_name: "Hope Church", your_name: "Casey Creator", email: "Casey@Hope.test" }

    assert_redirected_to new_project_path
    follow_redirect!
    assert_select "[data-organization-name]", "Hope Church"
    assert_select "[data-signed-in-as]", "Casey Creator"

    creator = Person.find_by!(email: "casey@hope.test")
    assert creator.admin
    assert_equal "hope-church", creator.organization.slug
  end

  test "creating an Organization emails the creator a welcome" do
    assert_enqueued_email_with WelcomeMailer, :welcome, args: ->(args) { args.first.email == "casey@hope.test" } do
      post organizations_path, params: { church_name: "Hope Church", your_name: "Casey Creator", email: "casey@hope.test" }
    end
  end

  test "creating an Organization without an email is refused and nothing is created" do
    assert_no_difference [ "Organization.count", "Person.count" ] do
      post organizations_path, params: { church_name: "Hope Church", your_name: "Casey Creator", email: "" }
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", "Email can't be blank"
    assert_select "input[name=church_name][value='Hope Church']"
  end
end
