require "test_helper"

class PeopleDirectoryTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:st_example)
    @row_names = -> { css_select("turbo-frame#people-results li a.font-semibold").map { |link| link.text.strip } }
  end

  test "each quick filter shows its people and the church-wide count" do
    sign_in_as_admin

    get people_path

    assert_select "nav[aria-label='Filter People'] a", count: 6
    assert_select "nav[aria-label='Filter People'] a", text: /\AEveryone\s+6\z/
    assert_select "nav[aria-label='Filter People'] a", text: /\AServing now\s+3\z/
    assert_select "nav[aria-label='Filter People'] a", text: /\ALeaders\s+2\z/
    assert_select "nav[aria-label='Filter People'] a", text: /\ANot yet asked\s+2\z/
    assert_select "nav[aria-label='Filter People'] a", text: /\AAway\s+0\z/
    assert_select "nav[aria-label='Filter People'] a", text: /\ANo email\s+1\z/

    get people_path, params: { filter: "serving" }
    assert_equal [ "Leo Leader", "Lucy Leader", "Vic Volunteer" ], @row_names.call
    assert_select "nav a[aria-current='page']", text: /Serving now/
  end

  test "the Leaders, Not yet asked and No email filters list the right people" do
    sign_in_as_admin

    get people_path, params: { filter: "leaders" }
    assert_equal [ "Leo Leader", "Lucy Leader" ], @row_names.call

    get people_path, params: { filter: "not_yet_asked" }
    assert_equal [ "Rowan Recipient", "Vera Volunteer" ], @row_names.call

    get people_path, params: { filter: "no_email" }
    assert_equal [ "Rowan Recipient" ], @row_names.call
  end

  test "Away lists people away today, with the date and never the note" do
    Unavailability.create!(organization: @organization, person: people(:volunteer), starts_on: Date.current - 2,
      ends_on: Date.current + 10, note: "Private trip details")
    sign_in_as_admin

    get people_path, params: { filter: "away" }

    assert_equal [ "Vic Volunteer" ], @row_names.call
    assert_select "span.status-chip", text: "Away until #{(Date.current + 10).strftime("%b %-d")}"
    assert_no_match "Private trip details", response.body
  end

  test "status chips name the Leader, the Admin, the never-asked, and the people who cannot sign in" do
    sign_in_as_admin

    get people_path

    assert_select "li", text: /Ada Admin/ do
      assert_select "span.status-chip", text: "Admin"
    end
    assert_select "li", text: /Leo Leader/ do
      assert_select "span.status-chip", text: "Leader"
      assert_select "span.status-chip-need", count: 0
    end
    assert_select "li", text: /Vera Volunteer/ do
      assert_select "span.status-chip-need", text: "Never asked"
    end
    assert_select "li", text: /Rowan Recipient/ do
      assert_select "span.status-chip-need", text: "Never asked"
      assert_select "span.status-chip", text: "Can't sign in"
    end
    assert_select "li", text: /Vic Volunteer/ do
      assert_select "span.status-chip-need", count: 0
    end
  end

  test "each row says only what the Person serves on" do
    sign_in_as_admin

    get people_path

    assert_select "li", text: /Vic Volunteer/ do
      assert_select "p", text: "Serving on Community Meal"
    end
    assert_select "li", text: /Lucy Leader/ do
      assert_select "p", text: "Serving on Building Cleanup and Community Meal"
    end
    assert_select "li", text: /Vera Volunteer/ do
      assert_select "p", text: "Not serving on an Active Project right now"
    end
  end

  test "rows keep contact details on the Person page" do
    sign_in_as_admin

    get people_path

    assert_no_match people(:volunteer).email, response.body
    assert_no_match people(:volunteer).phone, response.body
  end

  test "a filter and a search combine, and the search keeps the filter" do
    sign_in_as_admin

    get people_path, params: { filter: "serving", query: "lucy" }
    assert_equal [ "Lucy Leader" ], @row_names.call

    get people_path, params: { filter: "serving", query: "rowan" }
    assert_select "turbo-frame#people-results", text: /Nobody is in this list/, count: 0
    assert_select "turbo-frame#people-results p", text: /No people match "rowan"/
    assert_select "turbo-frame#people-results a[href=?]", people_path(filter: "serving"), text: "Clear search"
  end

  test "the search form keeps the current filter so live search stays inside it" do
    sign_in_as_admin

    get people_path, params: { filter: "leaders" }

    assert_select "form input[type=hidden][name=filter][value=leaders]"
    assert_select "nav a[aria-current='page']", text: /Leaders/
  end

  test "a filter with nobody in it says so and offers everyone" do
    sign_in_as_admin

    get people_path, params: { filter: "away" }

    assert_select "turbo-frame#people-results p", text: /Nobody is in this list right now/
    assert_select "turbo-frame#people-results a[href=?]", people_path, text: "Show everyone"
  end

  test "an unknown filter falls back to everyone" do
    sign_in_as_admin

    get people_path, params: { filter: "bogus" }

    assert_select "nav a[aria-current='page']", text: /Everyone/
    assert_equal 6, @row_names.call.size
  end

  test "the directory's query count does not grow with the number of People" do
    sign_in_as_admin
    baseline = directory_query_count

    3.times do |index|
      person = @organization.people.create!(name: "Extra Person #{index}", email: "extra#{index}@st-example.test")
      projects(:community_meal).memberships.create!(person: person, role: :volunteer)
      Unavailability.create!(organization: @organization, person: person, starts_on: Date.current, ends_on: Date.current + 3)
    end

    assert_equal baseline, directory_query_count
  end

  test "a volunteer gets 404 on the directory and on a person page" do
    sign_in_as_volunteer

    get people_path, params: { filter: "serving" }
    assert_response :not_found

    get person_path(people(:leader))
    assert_response :not_found
  end

  private
    # uncached: the query cache would otherwise answer repeat queries without running them, and the count would drift.
    def directory_query_count
      count = 0
      counter = ->(*, payload) { count += 1 unless %w[ SCHEMA TRANSACTION ].include?(payload[:name]) }
      ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get people_path }
      end
      assert_response :success
      count
    end
end
