require "test_helper"

class CalendarEventTest < ActiveSupport::TestCase
  test "timed Schedule items carry the church time zone" do
    event = CalendarEvent.new(schedule_items(:community_meal_lunch), url: "https://example.test/projects/1").to_ical

    assert_includes event, "DTSTART;TZID=America/Chicago:20270212T120000\r\n"
    assert_includes event, "DTEND;TZID=America/Chicago:20270212T130000\r\n"
    assert_includes event, "LOCATION:Fellowship Hall\r\n"
    assert_includes event, "URL:https://example.test/projects/1\r\n"
    assert_no_match(/(?<!\r)\n/, event)
  end

  test "untimed items occupy one whole day with an exclusive end" do
    item = schedule_items(:community_meal_arrival)
    event = CalendarEvent.new(item, url: "https://example.test").to_ical

    assert_includes event, "DTSTART;VALUE=DATE:20270212\r\n"
    assert_includes event, "DTEND;VALUE=DATE:20270213\r\n"
  end

  test "a Slot ends one hour later and keeps its UID after edits" do
    slot = projects(:community_meal).slots.create!(date: "2027-02-12", starts_at_time: "23:30", label: "Serve")
    first = CalendarEvent.new(slot, url: "https://example.test").to_ical
    slot.update!(label: "Clean up")
    second = CalendarEvent.new(slot, url: "https://example.test").to_ical

    assert_includes first, "DTSTART;TZID=America/Chicago:20270212T233000\r\n"
    assert_includes first, "DTEND;TZID=America/Chicago:20270213T003000\r\n"
    assert_equal first[/^UID:.+\r\n/], second[/^UID:.+\r\n/]
  end

  test "text is escaped and folded at UTF-8 character boundaries" do
    item = schedule_items(:community_meal_arrival)
    item.title = "Welcome, friends; \\ guests\r\nBEGIN:VEVENT " + "é" * 90
    event = CalendarEvent.new(item, url: "https://example.test").to_ical
    unfolded = event.gsub("\r\n ", "")

    assert_includes unfolded, 'SUMMARY:Welcome\, friends\; \\\\ guests\nBEGIN:VEVENT '
    assert_equal 1, event.scan(/^BEGIN:VEVENT\r$/).size
    assert event.valid_encoding?
    assert event.split("\r\n").all? { |line| line.bytesize <= 75 }
    assert_includes unfolded, "é" * 90
  end

  test "a missing date never becomes a fabricated event" do
    item = schedule_items(:community_meal_arrival)
    item.date = nil

    assert_raises(ArgumentError) { CalendarEvent.new(item, url: "https://example.test").to_ical }
  end

  test "the URL line is escaped like other text" do
    event = CalendarEvent.new(schedule_items(:community_meal_arrival), url: "https://example.test/a;b\r\nBEGIN:VEVENT").to_ical

    assert_includes event, 'URL:https://example.test/a\;b\nBEGIN:VEVENT'
    assert_equal 1, event.scan(/^BEGIN:VEVENT\r$/).size
  end
end
