require "test_helper"

class BudgetLinesTest < ActionDispatch::IntegrationTest
  test "a Leader creates, edits, and deletes budget lines" do
    sign_in_as_leader
    project = projects(:community_meal)

    assert_difference "BudgetLine.count", 1 do
      post project_budget_lines_path(project), params: {
        budget_line: {
          kind: "purchase",
          description: "Extra chairs",
          estimated: "150.00",
          actual: "",
          status: "pending",
          responsible_person_id: people(:volunteer).id
        }
      }
    end

    line = project.budget_lines.find_by!(description: "Extra chairs")
    assert_redirected_to project_path(project)
    assert_equal 150_00, line.estimated_cents
    assert_nil line.actual_cents

    follow_redirect!
    assert_match "Extra chairs", response.body
    assert_match "$150.00", response.body

    patch project_budget_line_path(project, line), params: {
      budget_line: {
        kind: "purchase",
        description: "Extra chairs and tables",
        estimated: "175.50",
        actual: "180.00",
        status: "paid",
        responsible_person_id: people(:volunteer).id
      }
    }

    assert_redirected_to project_path(project)
    line.reload
    assert_equal "Extra chairs and tables", line.description
    assert_equal 175_50, line.estimated_cents
    assert_equal 180_00, line.actual_cents

    assert_difference "BudgetLine.count", -1 do
      delete project_budget_line_path(project, line)
    end

    assert_redirected_to project_path(project)
    follow_redirect!
    assert_no_match "Extra chairs and tables", response.body
  end

  test "the responsible Volunteer updates status and actual but cannot change description" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    line = budget_lines(:community_meal_venue)

    patch project_budget_line_status_path(project, line), params: {
      budget_line: {
        description: "Hacked description",
        status: "reserved",
        actual: "950.00"
      }
    }

    assert_redirected_to project_path(project)
    line.reload
    assert_equal "Venue rental", line.description
    assert_equal "reserved", line.status
    assert_equal 950_00, line.actual_cents
  end

  test "a Volunteer cannot update another Person's budget line" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    line = budget_lines(:community_meal_supplies)

    get edit_project_budget_line_status_path(project, line)

    assert_response :not_found

    patch project_budget_line_status_path(project, line), params: {
      budget_line: { status: "paid", actual: "30.00" }
    }

    assert_response :not_found
  end

  test "totals treat blank actual costs as zero and show dollar amounts on the page" do
    sign_in_as_leader
    project = projects(:community_meal)

    get project_path(project)

    assert_response :success
    assert_select "section[aria-labelledby='tool-budget']" do |section|
      assert_select "dd", text: "$1,250.00"
      assert_select "dd", text: "$24.99"
      assert_select "h3", text: "Bookings"
      assert_select "h3", text: "Purchases"
      assert_match "$1,000.00", section.text
      assert_match "$250.00", section.text
    end
  end

  test "cancelled lines are excluded from every displayed total" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.budget_lines.create!(
      kind: :booking,
      description: "Cancelled bus",
      estimated_cents: 50_000,
      actual_cents: 40_000,
      status: :cancelled
    )

    assert_equal({ estimated_cents: 100_000, actual_cents: 0 }, project.budget_kind_totals(:booking))
    assert_equal({ estimated_cents: 125_000, actual_cents: 2_499 }, project.budget_grand_totals)

    get project_path(project)

    assert_response :success
    assert_select "section[aria-labelledby='tool-budget']" do
      assert_select "dt", text: "Estimated total"
      assert_select "dd", text: "$1,250.00", count: 1
      assert_select "dt", text: "Actual total"
      assert_select "dd", text: "$24.99", count: 1
      assert_select "h3", text: "Bookings"
      assert_select "p", text: /Estimated \$1,000\.00.*Actual \$0\.00/
    end
  end

  test "an unknown estimate is omitted from totals and named on its row" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.budget_lines.create!(kind: :purchase, description: "Paint", estimated_cents: nil)

    get project_path(project)

    assert_response :success
    assert_select "section[aria-labelledby='tool-budget']" do
      assert_select "dd", text: "$1,250.00"
      assert_select "li", text: /Paint/ do
        assert_select ".text-ink-2", text: /Estimate unknown/
      end
    end
  end

  test "dollar amounts round-trip exactly through forms and display" do
    sign_in_as_leader
    project = projects(:community_meal)

    post project_budget_lines_path(project), params: {
      budget_line: {
        kind: "purchase",
        description: "Round trip test",
        estimated: "19.99",
        actual: "19.99",
        status: "paid",
        responsible_person_id: people(:volunteer).id
      }
    }

    line = project.budget_lines.find_by!(description: "Round trip test")
    assert_equal 1999, line.estimated_cents
    assert_equal 1999, line.actual_cents

    get project_path(project)

    assert_response :success
    assert_match "$19.99", response.body
  end

  test "a Leader cannot assign a budget line to someone outside the Team" do
    sign_in_as_leader
    project = projects(:community_meal)

    assert_no_difference "BudgetLine.count" do
      post project_budget_lines_path(project), params: {
        budget_line: {
          kind: "purchase",
          description: "Restricted responsibility",
          responsible_person_id: people(:outsider).id
        }
      }
    end

    assert_response :unprocessable_content
    assert_select "li", "Responsible person must be on the Team"
  end

  test "a non-member gets 404 on budget routes" do
    sign_in_as_outsider
    project = projects(:community_meal)
    line = budget_lines(:community_meal_venue)

    get project_path(project)

    assert_response :not_found

    get new_project_budget_line_path(project)

    assert_response :not_found

    assert_no_difference "BudgetLine.count" do
      post project_budget_lines_path(project), params: {
        budget_line: { kind: "booking", description: "Sneak in", estimated: "1.00" }
      }
    end

    assert_response :not_found

    get edit_project_budget_line_path(project, line)

    assert_response :not_found

    get edit_project_budget_line_status_path(project, line)

    assert_response :not_found

    patch project_budget_line_path(project, line), params: {
      budget_line: { kind: "booking", description: "Changed", estimated: "1.00" }
    }

    assert_response :not_found
    assert_equal "Venue rental", line.reload.description
  end
end
