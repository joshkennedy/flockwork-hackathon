require "test_helper"

class PolicyTest < ActiveSupport::TestCase
  test "an Admin may view the deleted Projects list" do
    assert Policy.can?(people(:admin), :view_deleted, Project)
    assert_not Policy.can?(people(:leader), :view_deleted, Project)
  end
end
