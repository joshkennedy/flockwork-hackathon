require "test_helper"

class PolicyTest < ActiveSupport::TestCase
  test "only Admins and people who have led a Project may create Projects" do
    assert Policy.can?(people(:admin), :create, Project)
    assert Policy.can?(people(:leader), :create, Project)
    assert_not Policy.can?(people(:volunteer), :create, Project)
  end

  test "a Leader whose only Project is done may still create, but not once it is deleted" do
    leader = people(:other_leader)
    led = Project.where(id: leader.memberships.leader.select(:project_id))
    led.update_all(done_at: Time.current)

    assert Policy.can?(leader, :create, Project)
    assert_not Policy.can?(leader, :view_oversight, leader.organization)

    led.update_all(deleted_at: Time.current)

    assert_not Policy.can?(leader, :create, Project)
  end

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
