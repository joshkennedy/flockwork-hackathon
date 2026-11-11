require "test_helper"

class ListsTest < ActionDispatch::IntegrationTest
  test "a Leader creates a List with all five column types" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "list" ])

    assert_difference "List.count", 1 do
      post project_lists_path(project), params: { list: { name: "Retreat room plan" } }
    end

    list = project.lists.find_by!(name: "Retreat room plan")
    assert_redirected_to project_path(project)

    {
      "Room" => "text",
      "Beds" => "number",
      "Arrival" => "date",
      "Ready" => "checkbox",
      "Guest" => "person"
    }.each do |name, column_type|
      assert_difference "ListColumn.count", 1 do
        post project_list_list_columns_path(project, list), params: {
          list_column: { name: name, column_type: column_type }
        }
      end

      assert_redirected_to project_path(project)
    end

    assert_equal %w[text number date checkbox person], list.columns.pluck(:column_type)

    get project_path(project)

    assert_response :success
    assert_select "section[aria-labelledby='list-#{list.id}'] h3", "Retreat room plan"
    assert_select "section[aria-labelledby='list-#{list.id}'] th .column-name", text: "Room"
    assert_select "section[aria-labelledby='list-#{list.id}'] th .column-name", text: "Beds"
    assert_select "section[aria-labelledby='list-#{list.id}'] th .column-name", text: "Arrival"
    assert_select "section[aria-labelledby='list-#{list.id}'] th .column-name", text: "Ready"
    assert_select "section[aria-labelledby='list-#{list.id}'] th .column-name", text: "Guest"
  end

  test "a Team member adds, edits, and removes a row" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "list" ])
    list = lists(:room_assignments)

    assert_difference "ListRow.count", 1 do
      post project_list_list_rows_path(project, list), params: {
        list_row: {
          cells: {
            list_columns(:room).id.to_s => "Cedar",
            list_columns(:beds).id.to_s => "4",
            list_columns(:arrival).id.to_s => "2027-02-12",
            list_columns(:ready).id.to_s => "1",
            list_columns(:guest).id.to_s => people(:volunteer).id.to_s
          }
        }
      }
    end

    row = list.rows.first
    assert_redirected_to project_path(project)
    assert_equal "Cedar", row.cells.fetch(list_columns(:room).id.to_s)
    assert_equal 4, row.cells.fetch(list_columns(:beds).id.to_s)
    assert_equal "2027-02-12", row.cells.fetch(list_columns(:arrival).id.to_s)
    assert_equal true, row.cells.fetch(list_columns(:ready).id.to_s)
    assert_equal people(:volunteer).id, row.cells.fetch(list_columns(:guest).id.to_s)

    follow_redirect!
    assert_select "td", text: "Cedar"
    assert_select "td", text: "4"
    assert_select "td", text: "February 12, 2027"
    assert_select "td", text: "Vic Volunteer"

    patch project_list_list_row_path(project, list, row), params: {
      list_row: {
        cells: {
          list_columns(:room).id.to_s => "Cedar East",
          list_columns(:beds).id.to_s => "3.5",
          list_columns(:arrival).id.to_s => "2027-02-13",
          list_columns(:ready).id.to_s => "0",
          list_columns(:guest).id.to_s => people(:leader).id.to_s
        }
      }
    }

    assert_redirected_to project_path(project)
    assert_equal "Cedar East", row.reload.cells.fetch(list_columns(:room).id.to_s)
    assert_equal 3.5, row.cells.fetch(list_columns(:beds).id.to_s)
    assert_equal "2027-02-13", row.cells.fetch(list_columns(:arrival).id.to_s)
    assert_equal false, row.cells.fetch(list_columns(:ready).id.to_s)
    assert_equal people(:leader).id, row.cells.fetch(list_columns(:guest).id.to_s)

    assert_difference "ListRow.count", -1 do
      delete project_list_list_row_path(project, list, row)
    end

    assert_redirected_to project_path(project)
  end

  test "a Team member toggles a checkbox cell inline" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    list = lists(:room_assignments)
    column = list_columns(:ready)
    row = list.rows.create!(cells: { column.id.to_s => false })
    frame_id = ActionView::RecordIdentifier.dom_id(row, "column_#{column.id}")

    patch toggle_checkbox_project_list_list_row_path(project, list, row),
      params: { column_id: column.id },
      headers: { "Turbo-Frame" => frame_id }

    assert_response :success
    assert_equal true, row.reload.cells.fetch(column.id.to_s)
    assert_select "turbo-frame[id='#{frame_id}']"
    assert_select "form[action='#{toggle_checkbox_project_list_list_row_path(project, list, row)}']"

    patch toggle_checkbox_project_list_list_row_path(project, list, row),
      params: { column_id: column.id },
      headers: { "Turbo-Frame" => frame_id }

    assert_response :success
    assert_equal false, row.reload.cells.fetch(column.id.to_s)
  end

  test "a Person cell rejects a non-member and accepts a Team member" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    list = lists(:room_assignments)
    column = list_columns(:guest)

    assert_no_difference "ListRow.count" do
      post project_list_list_rows_path(project, list), params: {
        list_row: { cells: { column.id.to_s => people(:other_volunteer).id.to_s } }
      }
    end

    assert_response :unprocessable_content
    assert_select "li", "Guest must be a Team member of this Project"

    assert_difference "ListRow.count", 1 do
      post project_list_list_rows_path(project, list), params: {
        list_row: { cells: { column.id.to_s => people(:volunteer).id.to_s } }
      }
    end

    assert_redirected_to project_path(project)
    assert_equal people(:volunteer).id, list.rows.last.cells.fetch(column.id.to_s)
  end

  test "a Person cell rejects a Person from another Organization" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    list = lists(:room_assignments)
    column = list_columns(:guest)

    assert_no_difference "ListRow.count" do
      post project_list_list_rows_path(project, list), params: {
        list_row: { cells: { column.id.to_s => people(:outsider).id.to_s } }
      }
    end

    assert_response :unprocessable_content
    assert_select "li", "Guest must be a Team member of this Project"
  end

  test "a column type changes only when its cells are empty" do
    sign_in_as_leader
    project = projects(:community_meal)
    list = lists(:room_assignments)
    column = list_columns(:room)
    row = list.rows.create!(cells: { column.id.to_s => "Cedar" })

    patch project_list_list_column_path(project, list, column), params: {
      list_column: { name: column.name, column_type: "number" }
    }

    assert_response :unprocessable_content
    assert_select "li", "Delete the values in this column first, then change its type."
    assert_predicate column.reload, :text?

    row.update!(cells: {})
    patch project_list_list_column_path(project, list, column), params: {
      list_column: { name: column.name, column_type: "number" }
    }

    assert_redirected_to project_path(project)
    assert_predicate column.reload, :number?
  end

  test "a Leader renames, reorders, and removes columns" do
    sign_in_as_leader
    project = projects(:community_meal)
    list = lists(:room_assignments)
    room = list_columns(:room)
    beds = list_columns(:beds)
    guest = list_columns(:guest)
    ready = list_columns(:ready)
    arrival = list_columns(:arrival)
    row = list.rows.create!(cells: { arrival.id.to_s => "2027-02-12" })

    patch project_list_list_column_path(project, list, beds), params: {
      list_column: { name: "Sleeping spaces", column_type: "number" }
    }

    assert_redirected_to project_path(project)
    assert_equal "Sleeping spaces", beds.reload.name

    patch move_down_project_list_list_column_path(project, list, room)

    assert_redirected_to project_path(project)
    assert_equal [ "Sleeping spaces", "Room" ], list.columns.reload.first(2).map(&:name)

    patch move_up_project_list_list_column_path(project, list, guest)

    assert_redirected_to project_path(project)
    assert_equal [
      [ "Sleeping spaces", 1 ],
      [ "Room", 2 ],
      [ "Arrival", 3 ],
      [ "Guest", 4 ],
      [ "Ready", 5 ]
    ], list.columns.reload.map { |column| [ column.name, column.position ] }

    assert_difference "ListColumn.count", -1 do
      delete project_list_list_column_path(project, list, arrival)
    end

    assert_redirected_to project_path(project)
    assert_not row.reload.cells.key?(arrival.id.to_s)
  end

  test "a Volunteer cannot add columns" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "list" ])
    list = lists(:room_assignments)

    get project_path(project)

    assert_response :success
    assert_select "a", text: "Add Row", count: 1
    assert_select "a", text: "Add Column", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Move Up", count: 0

    assert_no_difference "ListColumn.count" do
      post project_list_list_columns_path(project, list), params: {
        list_column: { name: "Private notes", column_type: "text" }
      }
    end

    assert_response :not_found
  end

  test "a non-member gets 404 on List routes" do
    sign_in_as(:other_volunteer)
    project = projects(:community_meal)
    list = lists(:room_assignments)
    row = list.rows.create!

    get new_project_list_path(project)
    assert_response :not_found

    post project_list_list_columns_path(project, list), params: {
      list_column: { name: "Sneak in", column_type: "text" }
    }
    assert_response :not_found

    get new_project_list_list_row_path(project, list)
    assert_response :not_found

    delete project_list_list_row_path(project, list, row)
    assert_response :not_found
  end

  test "a Person from another Organization cannot read or change Lists, columns, or rows" do
    project = projects(:community_meal)
    list = lists(:room_assignments)
    column = list_columns(:room)
    row = list.rows.create!(cells: { column.id.to_s => "Cedar" })
    sign_in_as_outsider

    get new_project_list_path(project)
    assert_response :not_found

    assert_no_difference "List.count" do
      post project_lists_path(project), params: { list: { name: "Foreign List" } }
    end
    assert_response :not_found

    get edit_project_list_list_column_path(project, list, column)
    assert_response :not_found

    patch project_list_list_column_path(project, list, column), params: {
      list_column: { name: "Changed", column_type: "text" }
    }
    assert_response :not_found
    assert_equal "Room", column.reload.name

    get edit_project_list_list_row_path(project, list, row)
    assert_response :not_found

    patch project_list_list_row_path(project, list, row), params: {
      list_row: { cells: { column.id.to_s => "Changed" } }
    }
    assert_response :not_found
    assert_equal "Cedar", row.reload.cells.fetch(column.id.to_s)
  end
end
