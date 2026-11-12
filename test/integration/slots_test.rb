require "test_helper"

class SlotsTest < ActionDispatch::IntegrationTest
  test "a Leader creates, edits, and deletes Slots" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "signup_sheet" ])

    assert_difference "Slot.count", 1 do
      post project_slots_path(project), params: {
        slot: {
          date: "2027-02-15",
          starts_at_time: "18:30",
          label: "Serve dinner",
          capacity: 3
        }
      }
    end

    slot = project.slots.find_by!(label: "Serve dinner")
    assert_redirected_to project_path(project)
    follow_redirect!
    assert_select "section[aria-labelledby='tool-signup-sheet']", text: /Serve dinner/
    assert_select "section[aria-labelledby='tool-signup-sheet'] .badge-need", text: "3 spots left"
    assert_select "section[aria-labelledby='tool-signup-sheet'] .signup-row", text: /Mon, Feb 15, 2027/

    patch project_slot_path(project, slot), params: {
      slot: {
        date: "2027-02-16",
        starts_at_time: "19:00",
        label: "Clean up after dinner",
        capacity: 2
      }
    }

    assert_redirected_to project_path(project)
    slot.reload
    assert_equal Date.new(2027, 2, 16), slot.date
    assert_equal "19:00", slot.starts_at_time.strftime("%H:%M")
    assert_equal "Clean up after dinner", slot.label
    assert_equal 2, slot.capacity

    assert_difference "Slot.count", -1 do
      delete project_slot_path(project, slot)
    end

    assert_redirected_to project_path(project)
  end

  test "a Leader generates a fourteen-day run with literal first and last dates" do
    sign_in_as_leader
    project = projects(:community_meal)

    assert_difference "Slot.count", 14 do
      post project_slot_run_path(project), params: {
        slot_run: {
          start_date: "2027-02-15",
          end_date: "2027-02-28",
          starts_at_time: "18:00",
          label: "Bring dinner",
          capacity: 2
        }
      }
    end

    slots = project.slots.where(label: "Bring dinner").chronological.to_a
    assert_redirected_to project_path(project)
    assert_equal Date.new(2027, 2, 15), slots.first.date
    assert_equal Date.new(2027, 2, 28), slots.last.date
    assert_equal 2, slots.first.capacity
    assert_equal "18:00", slots.first.starts_at_time.strftime("%H:%M")
  end

  test "a Team member claims and releases a Slot" do
    member = sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "signup_sheet" ])
    slot = project.slots.create!(date: "2027-02-15", label: "Bring dessert", capacity: 2)

    assert_difference "SlotClaim.count", 1 do
      post project_slot_claim_path(project, slot)
    end

    assert_redirected_to project_path(project)
    assert_equal 1, slot.reload.claims_count
    follow_redirect!
    assert_select "section[aria-labelledby='tool-signup-sheet']", text: /1 of 2 filled/
    assert_select "section[aria-labelledby='tool-signup-sheet']", text: /#{member.name}/
    assert_select "form[action='#{project_slot_claim_path(project, slot)}'] button", text: "Release"

    assert_difference "SlotClaim.count", -1 do
      delete project_slot_claim_path(project, slot)
    end

    assert_redirected_to project_path(project)
    assert_equal 0, slot.reload.claims_count
  end

  test "a full Slot refuses another claim" do
    member = sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "signup_sheet" ])
    slot = project.slots.create!(date: "2027-02-15", label: "Bring bread", capacity: 1)
    slot.slot_claims.create!(person: people(:leader))

    assert_no_difference "SlotClaim.count" do
      post project_slot_claim_path(project, slot)
    end

    assert_redirected_to project_path(project)
    assert_equal "This Slot is full. Pick another one.", flash[:alert]
    assert_not slot.slot_claims.exists?(person: member)
    follow_redirect!
    assert_select "section[aria-labelledby='tool-signup-sheet']", text: /Leo Leader/
    assert_select "section[aria-labelledby='tool-signup-sheet'] .badge-need", count: 0
    assert_select "form[action='#{project_slot_claim_path(project, slot)}'] button", text: "Claim", count: 0
  end

  test "past Slots fold away and Leaders get a quiet claim button" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "signup_sheet" ])
    project.slots.create!(date: Date.current - 1, label: "Yesterday dinner", capacity: 1)
    today = project.slots.create!(date: Date.current, label: "Tonight dinner", capacity: 1)

    get project_path(project)

    assert_select "details[data-signup-past] summary.disclosure-bar", text: /Past Slots.*1 Slot/
    assert_select "details[data-signup-past] summary.disclosure-bar svg.disclosure-icon"
    assert_select "details[data-signup-past]", text: /Yesterday dinner/
    assert_select "details[data-signup-past]", text: /Tonight dinner/, count: 0
    assert_select "section[aria-labelledby='tool-signup-sheet']", text: /Tonight dinner/
    assert_select "form[action=?] .btn-primary", project_slot_claim_path(project, today), count: 0
  end

  test "Slot actions combine Add Slot with an explained bulk-create dialog" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools + [ "signup_sheet" ])

    get project_path(project)

    assert_select ".split-button a[data-action='slideout#open'][data-slideout-title-param='Add Slot']", text: /Add Slot/
    assert_select ".split-button summary[aria-label='Actions for Sign-up sheet']"
    assert_select ".actions-menu-panel a[data-action='dialog#open']", text: "Add Multiple Slots"
    assert_select "dialog.modal h2", text: "Add multiple Slots"
    assert_select "dialog.modal", text: /one Slot for every day in a date range/
    assert_select "dialog.modal form[action=?]", project_slot_run_path(project)
    assert_select "dialog.slideout turbo-frame#slot-form[data-slideout-target='frame']"
    assert_select "dialog.slideout turbo-frame#slot-form[data-action='turbo:submit-end->slideout#submitted']"
  end

  test "Slot forms keep validation inside the slideout frame but direct pages submit at the top" do
    sign_in_as_leader
    project = projects(:community_meal)

    get new_project_slot_path(project), headers: { "Turbo-Frame" => "slot-form" }
    assert_response :success
    assert_select "turbo-frame#slot-form form[data-turbo-frame]", count: 0

    get new_project_slot_path(project)
    assert_response :success
    assert_select "turbo-frame#slot-form form[data-turbo-frame='_top']"
  end

  test "Slot form offers Project Schedule sessions only when the Schedule tool has items" do
    sign_in_as_leader
    project = projects(:community_meal)
    session = schedule_items(:community_meal_opening)

    get new_project_slot_path(project)

    assert_select "form[data-controller~='slot-session']"
    assert_select "input[name='slot[date]'][data-slot-session-target='date']"
    assert_select "select[name='slot[schedule_item_id]'][data-slot-session-target='session'][data-action='slot-session#sync']" do
      assert_select "option[value='']", text: "No Schedule item"
      assert_select "option[value='#{session.id}'][data-date='2027-02-12']", text: /Opening Session/
    end

    project.update!(enabled_tools: project.enabled_tools - [ "schedule" ])
    get new_project_slot_path(project)

    assert_select "select[name='slot[schedule_item_id]']", count: 0
  end

  test "a Leader links a Slot to a Schedule session and the session controls its date" do
    sign_in_as_leader
    project = projects(:community_meal)
    session = schedule_items(:community_meal_day_two)

    post project_slots_path(project), params: {
      slot: {
        date: "2027-01-01",
        label: "Teacher",
        capacity: 2,
        schedule_item_id: session.id
      }
    }

    slot = project.slots.find_by!(label: "Teacher")
    assert_redirected_to project_path(project)
    assert_equal session, slot.schedule_item
    assert_equal session.date, slot.date
  end

  test "a Leader cannot link a Slot to another Project's Schedule item" do
    sign_in_as_leader
    project = projects(:community_meal)
    other_item = projects(:building_cleanup).schedule_items.create!(date: "2027-03-20", title: "Cleanup briefing")

    assert_no_difference "Slot.count" do
      post project_slots_path(project), params: {
        slot: {
          date: "2027-02-15",
          label: "Foreign session",
          capacity: 1,
          schedule_item_id: other_item.id
        }
      }
    end

    assert_response :unprocessable_content
    assert_select "li", "Schedule item must belong to the same Project"
  end

  test "Schedule and Sign-up rows show their linked session role" do
    sign_in_as_leader
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools | [ "signup_sheet" ])
    session = schedule_items(:community_meal_opening)
    slot = project.slots.create!(label: "Teacher", capacity: 2, schedule_item: session)
    slot.slot_claims.create!(person: people(:volunteer))

    get project_path(project)

    assert_select "li[data-schedule-item-id='#{session.id}']" do
      assert_select ".schedule-role-label", text: "Teacher"
      assert_select ".schedule-role-count", text: "1 of 2 filled"
      assert_select "a[href='##{dom_id(slot)}']", text: "Claim"
    end
    assert_select "li##{dom_id(slot)}" do
      assert_select ".signup-session", text: /Schedule item: Opening Session/
    end
  end

  test "a run longer than sixty days is refused" do
    sign_in_as_leader
    project = projects(:community_meal)

    assert_no_difference "Slot.count" do
      post project_slot_run_path(project), params: {
        slot_run: {
          start_date: "2027-02-01",
          end_date: "2027-04-02",
          label: "Bring dinner",
          capacity: 1
        }
      }
    end

    assert_response :unprocessable_content
    assert_select "li", "End date must be within 60 days of the start date"
  end

  test "a Leader cannot lower capacity below current claims" do
    sign_in_as_leader
    project = projects(:community_meal)
    slot = project.slots.create!(date: "2027-02-15", label: "Serve dinner", capacity: 2)
    slot.slot_claims.create!(person: people(:leader))
    slot.slot_claims.create!(person: people(:volunteer))

    patch project_slot_path(project, slot), params: {
      slot: {
        date: "2027-02-15",
        label: "Serve dinner",
        capacity: 1
      }
    }

    assert_response :unprocessable_content
    assert_select "li", "Capacity can't go below 2 people already signed up"
    assert_equal 2, slot.reload.capacity
  end

  test "leaving a Team releases the Person's Slot claims" do
    member = sign_in_as_volunteer
    project = projects(:community_meal)
    membership = memberships(:community_meal_volunteer)
    slot = project.slots.create!(date: "2027-02-15", label: "Bring salad", capacity: 2)
    slot.slot_claims.create!(person: member)

    assert_difference "SlotClaim.count", -1 do
      delete project_membership_path(project, membership)
    end

    assert_redirected_to projects_path
    assert_not slot.slot_claims.exists?(person: member)
  end

  test "a non-member gets 404 when claiming a Slot" do
    project = projects(:community_meal)
    slot = project.slots.create!(date: "2027-02-15", label: "Bring drinks", capacity: 2)
    non_member = organizations(:st_example).people.create!(name: "Nina Nonmember", email: "nina@st-example.test")
    sign_in_as(non_member)

    assert_no_difference "SlotClaim.count" do
      post project_slot_claim_path(project, slot)
    end

    assert_response :not_found
  end

  test "a Person from another Organization cannot read or change a Slot or its claims" do
    project = projects(:community_meal)
    slot = project.slots.create!(date: "2027-02-15", label: "Bring drinks", capacity: 2)
    sign_in_as_outsider

    get edit_project_slot_path(project, slot)
    assert_response :not_found

    patch project_slot_path(project, slot), params: {
      slot: { date: "2027-02-16", label: "Changed", capacity: 1 }
    }
    assert_response :not_found
    assert_equal [ Date.new(2027, 2, 15), "Bring drinks", 2 ],
      slot.reload.attributes.values_at("date", "label", "capacity")

    assert_no_difference "SlotClaim.count" do
      post project_slot_claim_path(project, slot)
    end

    assert_response :not_found
  end

  test "a Volunteer cannot manage Slots and an Admin can" do
    sign_in_as_volunteer
    project = projects(:community_meal)

    get new_project_slot_path(project)
    assert_response :not_found

    get new_project_slot_run_path(project)
    assert_response :not_found

    sign_in_as_admin

    assert_difference "Slot.count", 1 do
      post project_slots_path(project), params: {
        slot: { date: "2027-02-15", label: "Admin Slot", capacity: 1 }
      }
    end

    assert_redirected_to project_path(project)
  end
end
