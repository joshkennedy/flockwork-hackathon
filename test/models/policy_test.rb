require "test_helper"

class PolicyTest < ActiveSupport::TestCase
  test "only an Admin may manage a directory source" do
    assert Policy.can?(people(:admin), :manage_directory_source, organizations(:st_example))
    assert_not Policy.can?(people(:leader), :manage_directory_source, organizations(:st_example))
    assert_not Policy.can?(people(:outsider), :manage_directory_source, organizations(:st_example))
  end

  test "an Admin may view the deleted Projects list" do
    assert Policy.can?(people(:admin), :view_deleted, Project)
    assert_not Policy.can?(people(:leader), :view_deleted, Project)
  end

  test "Recipients visibility follows Team membership" do
    project = projects(:community_meal)

    assert Policy.can?(people(:volunteer), :view_recipients, project)
    assert Policy.can?(people(:admin), :view_recipients, project)
    assert_not Policy.can?(people(:other_volunteer), :view_recipients, project)
    assert Policy.can?(people(:leader), :manage_recipients, project)
    assert_not Policy.can?(people(:volunteer), :manage_recipients, project)
  end

  test "only Project Leaders and Admins may duplicate" do
    project = projects(:community_meal)

    assert Policy.can?(people(:leader), :duplicate, project)
    assert Policy.can?(people(:other_leader), :duplicate, project)
    assert Policy.can?(people(:admin), :duplicate, project)
    assert_not Policy.can?(people(:volunteer), :duplicate, project)
    assert_not Policy.can?(people(:other_volunteer), :duplicate, project)
    assert_not Policy.can?(people(:outsider), :duplicate, project)
  end
end
