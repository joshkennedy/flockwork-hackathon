require "test_helper"

class DashboardRefreshTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "project changes invalidate only their church dashboard without carrying private content" do
    project = projects(:community_meal)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ project.organization, :dashboard ])
    other_stream = Turbo::StreamsChannel.send(:stream_name_from, [ organizations(:outsider_church), :dashboard ])

    assert_no_broadcasts other_stream do
      messages = capture_broadcasts(stream) { project.update!(name: "Private planning detail") }
      assert_equal 1, messages.size
      assert_includes messages.first, 'action="refresh"'
      assert_not_includes messages.first, "Private planning detail"
    end
  end

  test "task changes invalidate the parent church dashboard" do
    project = projects(:community_meal)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ project.organization, :dashboard ])

    assert_broadcasts(stream, 1) { project.tasks.create!(title: "Prepare") }
  end

  test "removing a membership invalidates dashboards so access is checked again" do
    membership = memberships(:community_meal_volunteer)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ membership.project.organization, :dashboard ])

    assert_broadcasts(stream, 1) { membership.destroy! }
  end

  test "claim changes invalidate the dashboard's open spot count" do
    project = projects(:community_meal)
    slot = project.slots.create!(label: "Serve", date: Date.tomorrow, capacity: 1)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ project.organization, :dashboard ])

    claim = nil
    assert_broadcasts(stream, 1) { claim = slot.slot_claims.create!(person: people(:volunteer)) }
    assert_broadcasts(stream, 1) { claim.destroy! }
  end

  test "refresh callbacks do not cache organization settings on the project" do
    project = projects(:building_cleanup)
    organization = organizations(:st_example)
    project.association(:organization).reset

    project.update!(skills_needed: [ "Handyman" ])
    assert_not project.association(:organization).loaded?
    organization.update!(overextended_limit: 1)

    assert_equal 1, project.organization.overextended_limit
  end
end
