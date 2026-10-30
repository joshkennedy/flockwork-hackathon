require "test_helper"

class WorkspaceCreationTest < ActionDispatch::IntegrationTest
  test "creating a Workspace makes the creator its Admin, signs them in, and lands on its home" do
    post workspaces_path, params: { church_name: "Hope Church", your_name: "Casey Creator", email: "Casey@Hope.test" }

    assert_redirected_to "/hope-church"
    follow_redirect!
    assert_select "h1", "Hope Church"
    assert_select "p", "Signed in as Casey Creator"

    creator = Person.find_by!(email: "casey@hope.test")
    assert creator.admin
    assert_equal "hope-church", creator.workspace.slug
  end

  test "creating a Workspace without an email is refused and nothing is created" do
    assert_no_difference [ "Workspace.count", "Person.count" ] do
      post workspaces_path, params: { church_name: "Hope Church", your_name: "Casey Creator", email: "" }
    end

    assert_redirected_to root_path
    assert_equal "Email can't be blank", flash[:alert]
  end
end
