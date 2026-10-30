require "test_helper"

class DirectorySources::PlanningCenterTest < ActiveSupport::TestCase
  test "yields the seeded Planning Center people through the directory source contract" do
    people = VCR.use_cassette("planning_center/people") do
      source.each_person.to_a
    end

    assert_equal 26, people.length
    assert_equal %i[external_id name email phone], people.first.keys
    assert people.all? { |person| person.keys == %i[external_id name email phone] }
    assert_includes people, {
      external_id: people.find { |person| person[:name] == "Daniel Okafor" }.fetch(:external_id),
      name: "Daniel Okafor",
      email: "daniel.okafor@grace.example",
      phone: "202-555-0100"
    }
    assert people.any? { |person| person[:name] == "Sofia Nguyen" && person[:email].nil? }
  end

  test "maps rejected credentials to a plain message" do
    error = assert_raises(DirectorySources::Error) do
      VCR.use_cassette("planning_center/unauthorized") do
        DirectorySources::PlanningCenter.new(app_id: "wrong", secret: "wrong").each_person.to_a
      end
    end

    assert_equal "Planning Center didn't accept those credentials.", error.message
  end

  test "committed cassettes filter credentials" do
    cassette_contents = Rails.root.glob("test/vcr_cassettes/**/*.yml").map(&:read).join

    assert_includes cassette_contents, "<PCO_AUTHORIZATION>"
    assert_not_includes cassette_contents, ENV["PCO_APP_ID"] if ENV["PCO_APP_ID"].present?
    assert_not_includes cassette_contents, ENV["PCO_SECRET"] if ENV["PCO_SECRET"].present?
  end

  private
    def source
      DirectorySources::PlanningCenter.new(
        app_id: ENV.fetch("PCO_APP_ID", "cassette-app-id"),
        secret: ENV.fetch("PCO_SECRET", "cassette-secret")
      )
    end
end
