require "test_helper"

class PolicyTest < ActiveSupport::TestCase
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
end
