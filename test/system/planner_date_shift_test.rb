require "application_system_test_case"

class PlannerDateShiftSystemTest < ApplicationSystemTestCase
  test "explicit date changes remain a reviewed suggestion until Keep and acceptance" do
    original_provider = Rails.configuration.x.planner_provider
    person = people(:leader)
    project = projects(:community_meal)
    original_date = project.starts_on
    Rails.configuration.x.planner_provider = Planner::Providers::Fake.new([
      Planner::Response.new(card: nil, finished: true, added: [ { kind: "shift_project_dates", fields: { days: 7 } } ], removed_ids: [])
    ])
    visit sign_in_link_path(person.generate_token_for(:sign_in))
    click_button "Sign In"
    assert_current_path home_path
    visit new_project_planner_session_path(project)
    fill_in "Describe this plan in one sentence", with: "Push everything a week later"
    click_button "Start Planning"
    assert_text "Move all saved Project, Task, Schedule, Slot and List dates 7 days"
    assert_text "Keep existing claims and assignments"
    assert_equal original_date, project.reload.starts_on
    click_button "Keep"
    assert_text "Currently kept"
    click_button "Accept All Kept and Edited"
    assert_current_path project_path(project)
    assert_equal original_date + 7, project.reload.starts_on
  ensure
    Rails.configuration.x.planner_provider = original_provider
  end
end
