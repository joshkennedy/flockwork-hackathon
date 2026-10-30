require "test_helper"

class PlannerNameRedactorTest < ActiveSupport::TestCase
  test "redacts directory full names and first names with literal word matching" do
    workspace = workspaces(:st_example)
    redactor = Planner::NameRedactor.new(workspace)

    assert_equal "Ask [name] and [name] to cook, but leave Leonardo and violet alone.",
      redactor.call("Ask Leo Leader and VIC to cook, but leave Leonardo and violet alone.")
  end

  test "leaves text without a directory name unchanged" do
    redactor = Planner::NameRedactor.new(workspaces(:st_example))

    assert_equal "We'll cook together.", redactor.call("We'll cook together.")
  end
end
