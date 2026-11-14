require "test_helper"

class ProjectToolSlideoutsTest < ActionDispatch::IntegrationTest
  setup do
    @person = sign_in_as_leader
    @project = projects(:community_meal)
    @project.update!(enabled_tools: (@project.enabled_tools + [ "list" ]).uniq)
    @task = @project.tasks.create!(title: "Set tables")
    @schedule_item = @project.schedule_items.create!(date: "2027-02-12", title: "Doors open")
    @budget_line = @project.budget_lines.create!(kind: :purchase, description: "Name tags", responsible_person: @person)
    @list = lists(:room_assignments)
    @list_row = @list.rows.create!(cells: { list_columns(:room).id.to_s => "Cedar" })
    @message = @project.messages.create!(author: @person, body: "Bring serving spoons")
  end

  test "Project tool actions open their forms in the existing slideout frames" do
    get project_path(@project)

    assert_response :success
    assert_slideout_link "tool-tasks", new_project_task_path(@project), "Add Task", "task-form"
    assert_slideout_link "tool-tasks", edit_project_task_path(@project, @task), "Edit Task", "task-form"
    assert_slideout_link "tool-schedule", new_project_schedule_item_path(@project), "Add Schedule Item", "schedule-item-form"
    assert_slideout_link "tool-schedule", edit_project_schedule_item_path(@project, @schedule_item), "Edit Schedule Item", "schedule-item-form"
    assert_slideout_link "tool-budget", new_project_budget_line_path(@project, kind: "booking"), "Add Booking", "budget-form"
    assert_slideout_link "tool-budget", edit_project_budget_line_path(@project, @budget_line), "Edit Budget Line", "budget-form"
    assert_slideout_link "tool-budget", edit_project_budget_line_status_path(@project, @budget_line), "Update Budget Status", "budget-form"
    assert_slideout_link "tool-list", new_project_list_path(@project), "Add List", "list-form"
    assert_slideout_link "tool-list", new_project_list_list_column_path(@project, @list), "Add Column", "list-form"
    assert_slideout_link "tool-list", edit_project_list_list_column_path(@project, @list, list_columns(:room)), "Edit Column", "list-form"
    assert_slideout_link "tool-list", new_project_list_list_row_path(@project, @list), "Add Row", "list-form"
    assert_slideout_link "tool-list", edit_project_list_list_row_path(@project, @list, @list_row), "Edit Row", "list-form"
    assert_slideout_link "tool-messages", edit_project_message_path(@project, @message), "Edit Message", "message-form"
  end

  test "direct form URLs submit the full page while slideout requests stay in their frame" do
    paths_by_frame = {
      "task-form" => [ new_project_task_path(@project), edit_project_task_path(@project, @task) ],
      "schedule-item-form" => [ new_project_schedule_item_path(@project), edit_project_schedule_item_path(@project, @schedule_item) ],
      "budget-form" => [
        new_project_budget_line_path(@project, kind: "purchase"),
        edit_project_budget_line_path(@project, @budget_line),
        edit_project_budget_line_status_path(@project, @budget_line)
      ],
      "list-form" => [
        new_project_list_path(@project),
        new_project_list_list_column_path(@project, @list),
        edit_project_list_list_column_path(@project, @list, list_columns(:room)),
        new_project_list_list_row_path(@project, @list),
        edit_project_list_list_row_path(@project, @list, @list_row)
      ],
      "message-form" => [ edit_project_message_path(@project, @message) ]
    }

    paths_by_frame.each do |frame_id, paths|
      paths.each do |path|
        get path
        assert_response :success, "direct GET #{path}"
        assert_select "turbo-frame##{frame_id} form[data-turbo-frame='_top']", count: 1

        get path, headers: { "Turbo-Frame" => frame_id }
        assert_response :success, "frame GET #{path}"
        assert_select "turbo-frame##{frame_id} form", count: 1
        assert_select "turbo-frame##{frame_id} form[data-turbo-frame='_top']", count: 0
      end
    end
  end

  private
    def assert_slideout_link(section_id, path, title, frame_id)
      assert_select "section[aria-labelledby='#{section_id}'][data-controller='slideout']" do
        assert_select "a[href='#{path}'][data-action='slideout#open'][data-slideout-title-param='#{title}']", count: 1
        assert_select "dialog.slideout turbo-frame##{frame_id}[data-slideout-target='frame'][data-action='turbo:submit-end->slideout#submitted']", count: 1
      end
    end
end
