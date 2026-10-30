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
    assert_select "section[aria-labelledby='tool-signup-sheet']", text: /0 of 3 filled/
    assert_select "section[aria-labelledby='tool-signup-sheet'] h3", text: "Monday, February 15"

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
    assert_equal "This slot is full.", flash[:alert]
    assert_not slot.slot_claims.exists?(person: member)
    follow_redirect!
    assert_select "section[aria-labelledby='tool-signup-sheet']", text: /Full/
    assert_select "section[aria-labelledby='tool-signup-sheet']", text: /Leo Leader/
    assert_select "form[action='#{project_slot_claim_path(project, slot)}'] button", text: "Claim", count: 0
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
    assert_select "li", "Capacity cannot be less than the current 2 claims"
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
    non_member = workspaces(:st_example).people.create!(name: "Nina Nonmember", email: "nina@st-example.test")
    sign_in_as(non_member)

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
