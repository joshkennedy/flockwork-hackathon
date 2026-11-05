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

  test "stops following pagination at a page cap" do
    cap = 50
    cap.times do |index|
      page = index + 1
      url = page == 1 ? DirectorySources::PlanningCenter::PEOPLE_URL : "#{people_root}?offset=#{index * 100}"
      next_url = "#{people_root}?offset=#{page * 100}"
      stub_people_page(url, id: page.to_s, next_url:)
    end
    stub_people_page("#{people_root}?offset=#{cap * 100}", id: (cap + 1).to_s, next_url: nil)

    error = assert_raises(DirectorySources::Error) { source.each_person.to_a }

    assert_equal "Planning Center returned too many pages. Nothing was changed.", error.message
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

    def people_root
      "https://api.planningcenteronline.com/people/v2/people"
    end

    def stub_people_page(url, id:, next_url:)
      stub_request(:get, url).to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate(
          data: [ { type: "Person", id:, attributes: { name: "Paged Person #{id}" }, relationships: {} } ],
          included: [],
          links: { next: next_url }
        )
      )
    end
end
