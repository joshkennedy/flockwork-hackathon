require "test_helper"

class PlannerNameRedactorTest < ActiveSupport::TestCase
  test "redacts directory full names and first names with literal word matching" do
    organization = organizations(:st_example)
    redactor = Planner::NameRedactor.new(organization)

    assert_equal "Ask [name] and [name] to cook, but leave Leonardo and violet alone.",
      redactor.call("Ask Leo Leader and VIC to cook, but leave Leonardo and violet alone.")
  end

  test "a leading article or title is not treated as a first name" do
    organization = organizations(:st_example)
    organization.people.create!(name: "The Alvarez Family")
    organization.people.create!(name: "Dr. Ruth Park")

    assert_equal "Learn the work, then ask [name] and [name] (and the doctor).",
      Planner::NameRedactor.new(organization).call("Learn the work, then ask The Alvarez Family and Ruth (and the doctor).")
  end

  test "leaves text without a directory name unchanged" do
    redactor = Planner::NameRedactor.new(organizations(:st_example))

    assert_equal "We'll cook together.", redactor.call("We'll cook together.")
  end
end
