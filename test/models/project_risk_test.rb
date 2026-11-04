require "test_helper"

class ProjectRiskTest < ActiveSupport::TestCase
  setup do
    @project = projects(:community_meal)
    @today = Date.new(2027, 2, 7)
    @project.update!(enabled_tools: %w[tasks signup_sheet])
  end

  test "counts remaining spots in seven calendar days and only unfinished overdue tasks" do
    @project.slots.create!(label: "Setup", date: @today, capacity: 4, claims_count: 1)
    @project.slots.create!(label: "Last day", date: @today + 6, capacity: 2)
    @project.slots.create!(label: "Later", date: @today + 7, capacity: 8)
    @project.slots.create!(label: "Past", date: @today - 1, capacity: 8)
    @project.slots.create!(label: "Covered", date: @today, capacity: 1, claims_count: 1)
    @project.tasks.create!(title: "Overdue", due_on: @today - 1)
    @project.tasks.create!(title: "Today", due_on: @today)
    @project.tasks.create!(title: "No date")
    @project.tasks.create!(title: "Done", due_on: @today - 2, completed_at: Time.current)

    risk = ProjectRisk.new(@project, today: @today)
    assert_equal 5, risk.open_spots
    assert_equal 1, risk.overdue_tasks
    assert_equal 5, risk.days_until_start
    assert risk.attention_needed?
    assert_equal "signup_sheet", risk.action_tool
  end

  test "no dates still permits overdue work and chooses tasks" do
    @project.update!(starts_on: nil, ends_on: nil)
    @project.tasks.create!(title: "Overdue", due_on: @today - 1)
    risk = ProjectRisk.new(@project, today: @today)
    assert_nil risk.days_until_start
    assert_equal "tasks", risk.action_tool
    assert risk.attention_needed?
  end

  test "disabled tools and inactive projects do not raise needs" do
    @project.slots.create!(label: "Setup", date: @today, capacity: 4)
    @project.tasks.create!(title: "Overdue", due_on: @today - 1)
    @project.update!(enabled_tools: [])
    refute ProjectRisk.new(@project, today: @today).attention_needed?
    @project.update!(enabled_tools: %w[tasks signup_sheet], done_at: Time.current)
    risk = ProjectRisk.new(@project, today: @today)
    refute risk.attention_needed?
    assert_nil risk.action_tool
    assert_nil risk.days_until_start
  end

  test "pending invitations count only unanswered invitations for this Project" do
    invitation = @project.invitations.create!(organization: @project.organization,
      person: people(:admin), inviter: people(:leader), role: :volunteer)
    assert_equal 1, ProjectRisk.new(@project, today: @today).pending_invitations
    invitation.decline!
    assert_equal 0, ProjectRisk.new(@project, today: @today).pending_invitations
  end

  test "facts stay scoped to the Project" do
    projects(:building_cleanup).tasks.create!(title: "Other Project overdue", due_on: @today - 1)
    risk = ProjectRisk.new(@project, today: @today)
    assert_equal 0, risk.overdue_tasks
    refute risk.attention_needed?
    assert_nil risk.action_tool
  end
end
