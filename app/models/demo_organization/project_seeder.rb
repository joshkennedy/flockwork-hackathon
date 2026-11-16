class DemoOrganization::ProjectSeeder
  PHOTO_ROOT = Rails.root.join("app/assets/images/marketing/photos")
  HANDBOOK_PATH = Rails.root.join("test/fixtures/files/handbook.pdf")

  def initialize(organization:, people:)
    @organization = organization
    @people = people
    @projects = {}
  end

  def seed!
    seed_womens_retreat!
    seed_meal_train!
    seed_fall_church_picnic!
    seed_vbs_projects!
    seed_workday!
    seed_mens_retreat!
    seed_kids_night!
    seed_community_serve!
    seed_welcome_team!
    seed_thanksgiving_baskets!
    seed_parking_team!
    seed_finished_projects!
    seed_people_history!
  end

  private
    attr_reader :organization, :people, :projects

    def seed_womens_retreat!
      project = create_project!(
        name: "Women's Fall Retreat",
        creator: "Grace Kim",
        description: "A quiet weekend for the women of Grace Fellowship to rest, connect, and grow together.",
        starts_on: Date.current + 5.weeks,
        ends_on: Date.current + 5.weeks + 2.days,
        created_at: 10.weeks.ago,
        skills: [ "Hospitality", "Prayer", "Music" ],
        tools: %w[tasks schedule signup_sheet budget messages list],
        photo: "womens-retreat.webp",
        alt: "Women talking together beside a lake at retreat."
      )
      invite!(project, "Maria Lopez", "Grace Kim", :volunteer, :accepted, 9.weeks.ago)
      invite!(project, "Tasha Williams", "Grace Kim", :volunteer, :accepted, 8.weeks.ago)
      invite!(project, "Abigail Turner", "Grace Kim", :volunteer, :pending, 4.days.ago)
      invite!(project, "Gabriel White", "Grace Kim", :volunteer, :pending, 3.days.ago)
      invite!(project, "Natalie King", "Grace Kim", :volunteer, :declined, 6.weeks.ago)
      invite!(project, "Isaiah Green", "Grace Kim", :leader, :declined, 6.weeks.ago)
      invite!(project, "Julia Adams", "Grace Kim", :volunteer, :pending, 2.days.ago)

      add_tasks!(project, [
        [ "Confirm retreat center room list", "Maria Lopez", project.starts_on - 21.days, false ],
        [ "Prepare welcome bags", "Tasha Williams", project.starts_on - 7.days, false ],
        [ "Print the weekend schedule", "Grace Kim", project.starts_on - 3.days, true ]
      ])
      add_schedule!(project, [
        [ project.starts_on, "17:00", "Arrival and room check-in", "Retreat lodge" ],
        [ project.starts_on, "19:00", "Dinner and opening prayer", "Dining room" ],
        [ project.starts_on + 1.day, "09:00", "Morning session", "Lakeside room" ]
      ])
      add_slots!(project, [
        [ project.starts_on, "16:30", "Welcome table", 2, [ "Maria Lopez", "Tasha Williams" ] ],
        [ project.starts_on, "18:00", "Dinner setup", 2, [ "Tasha Williams" ] ],
        [ project.starts_on + 1.day, "08:00", "Breakfast setup", 2, [ "Maria Lopez" ] ]
      ])
      add_budget!(project, [
        [ :booking, "Retreat lodge", 240_000, nil, :reserved, "Grace Kim" ],
        [ :purchase, "Welcome bag supplies", 24_000, 21_650, :paid, "Tasha Williams" ],
        [ :purchase, "Printed workbooks", 18_000, 17_400, :paid, "Maria Lopez" ]
      ])
      root = message!(project, "Maria Lopez", "Room assignments are ready. Please review the packing list before Friday.", 3.weeks.ago)
      message!(project, "Grace Kim", "I added rain jackets and refillable water bottles. Thank you!", 20.days.ago, parent: root)
      add_list!(project, "Packing list", [ "Item", "Packed" ], [
        [ "Bible and notebook", true ],
        [ "Rain jacket", false ],
        [ "Refillable water bottle", true ],
        [ "Closed-toe walking shoes", false ]
      ])
    end

    def seed_meal_train!
      project = create_project!(
        name: "Meal Train for the Alvarez Family",
        creator: "Grace Kim",
        description: "Provide a warm dinner each evening while the Alvarez family focuses on recovery.",
        starts_on: Date.current - 10.days,
        ends_on: Date.current + 18.days,
        created_at: 6.weeks.ago,
        skills: [ "Cooking", "Driving" ],
        tools: %w[recipients signup_sheet messages],
        photo: "meal-train-door.webp",
        alt: "A volunteer delivering a covered meal at a front door."
      )
      add_members!(project, {
        "Maria Lopez" => :leader,
        "Ruth Bennett" => :volunteer,
        "Aaron Price" => :volunteer,
        "Lydia Evans" => :volunteer,
        "Josiah Clark" => :volunteer,
        "Miriam Wright" => :volunteer,
        "David Hall" => :volunteer
      }, joined_at: 5.weeks.ago)
      recipient = add_recipient!(project, "The Alvarez Family", [
        [ "Maria Lopez", :team, "Allergic to tree nuts" ],
        [ "Maria Lopez", :team, "Drop off at the side door after 5pm" ],
        [ "Grace Kim", :leaders, "Dad's surgery recovery may take 8 weeks" ]
      ])
      root = message!(project, "Maria Lopez", "Thank you for helping the Alvarez family with dinners.", 5.weeks.ago)
      message!(project, "Grace Kim", "Please label dishes with ingredients and your name.", 34.days.ago, parent: root)
      add_daily_slots!(project, project.starts_on, project.ends_on, "Dinner", "18:00", 1)
      project.slots.chronological.first(14).each_with_index do |slot, index|
        claim!(slot, "Ruth Bennett", created_at: (13 - index).days.ago)
      end
      project.enable_public_link!
      add_public_helpers!(project)
      recipient.update_columns(created_at: 5.weeks.ago, updated_at: 5.weeks.ago)
    end

    def seed_fall_church_picnic!
      project = create_project!(
        name: "Fall Church Picnic",
        creator: "Maria Lopez",
        description: "Share lunch on the church lawn and bring enough for everyone to try something.",
        starts_on: Date.current + 3.weeks,
        ends_on: Date.current + 3.weeks,
        created_at: 3.weeks.ago,
        skills: [ "Cooking", "Hospitality", "Setup and teardown" ],
        tools: %w[signup_sheet messages],
        photo: "kitchen-crew.webp",
        alt: "Volunteers preparing food together in a church kitchen.",
        open_team: true
      )
      add_members!(project, { "Sam Chen" => :volunteer, "Grace Kim" => :volunteer }, joined_at: 2.weeks.ago)

      prompt = "What are you bringing?"
      categories = [
        [ "Main dishes", 8, prompt, { "Maria Lopez" => "Baked ziti", "Sam Chen" => "Pulled pork", "Grace Kim" => "Lentil casserole" } ],
        [ "Sides", 10, prompt, { "Sam Chen" => "Potato salad", "Grace Kim" => "Coleslaw" } ],
        [ "Desserts", 8, prompt, { "Maria Lopez" => "Apple crisp", "Grace Kim" => "Brownies" } ],
        [ "Drinks", 6, prompt, { "Sam Chen" => "Iced tea", "Maria Lopez" => "Lemonade" } ],
        [ "Setup helpers", 4, nil, { "Maria Lopez" => nil, "Sam Chen" => nil } ]
      ]
      categories.each do |label, capacity, claim_prompt, claims|
        slot = project.slots.create!(
          date: project.starts_on,
          starts_at_time: "11:30",
          label:,
          capacity:,
          claim_prompt:,
          created_at: project.created_at + 2.days,
          updated_at: project.created_at + 2.days
        )
        claims.each do |name, note|
          claim!(slot, name, note:, created_at: project.created_at + 1.week)
        end
      end

      root = message!(project, "Maria Lopez", "The picnic sign-up is open. Add what you are bringing so we get a good mix.", 5.days.ago)
      message!(project, "Sam Chen", "I can bring serving spoons and labels for the food tables.", 4.days.ago, parent: root)
      project.enable_public_link!
    end

    def seed_vbs_projects!
      starts_on = Date.new(Date.current.year - 1, 6, 16)
      source = create_project!(
        name: "Vacation Bible School #{Date.current.year - 1}",
        creator: "Naomi Patel",
        description: "A week of Bible stories, games, crafts, and music for children in our community.",
        starts_on:,
        ends_on: starts_on + 4.days,
        created_at: starts_on - 4.months,
        done_at: starts_on + 5.days,
        skills: [ "Teaching", "Childcare", "Music" ],
        tools: %w[tasks schedule signup_sheet budget list],
        photo: "vbs-field.webp",
        alt: "Children playing a group game on a sunny field."
      )
      add_members!(source, { "Elijah Brooks" => :leader, "Maria Lopez" => :leader }, joined_at: starts_on - 3.months)
      add_tasks!(source, [
        [ "Prepare classroom supply bins", "Naomi Patel", starts_on - 7.days, true ],
        [ "Confirm volunteer background checks", "Elijah Brooks", starts_on - 14.days, true ],
        [ "Print family check-in sheets", "Maria Lopez", starts_on - 2.days, true ],
        [ "Set up welcome table", "Naomi Patel", starts_on - 1.day, true ],
        [ "Pack daily snack carts", "Elijah Brooks", starts_on, true ],
        [ "Post classroom signs", "Maria Lopez", starts_on - 1.day, true ]
      ])
      add_schedule!(source, [
        [ starts_on, "08:30", "Volunteer huddle", "Fellowship Hall" ],
        [ starts_on, "09:00", "Opening worship", "Sanctuary" ],
        [ starts_on + 2.days, "11:30", "Water games", "East Lawn" ],
        [ starts_on + 4.days, "11:45", "Family closing program", "Sanctuary" ]
      ])
      add_daily_slots!(source, starts_on, starts_on + 4.days, "Check-in helper", "08:15", 3)
      source.slots.each do |slot|
        %w[Elijah\ Brooks Maria\ Lopez Naomi\ Patel].each { |name| claim!(slot, name, created_at: starts_on - 1.month) }
      end
      add_budget!(source, [
        [ :booking, "Inflatable obstacle course", 85_000, 82_500, :paid, "Naomi Patel" ],
        [ :purchase, "Craft supplies", 42_000, 39_850, :paid, "Elijah Brooks" ],
        [ :purchase, "Snacks and drinks", 31_500, 30_975, :paid, "Maria Lopez" ],
        [ :purchase, "Printed curriculum", 24_000, 24_000, :paid, "Naomi Patel" ]
      ])
      add_list!(source, "Classroom assignments", [ "Classroom", "Age group", "Ready" ], [
        [ "101", "Preschool", true ],
        [ "102", "Kindergarten", true ],
        [ "201", "Grades 1-2", true ],
        [ "202", "Grades 3-5", true ]
      ])
      source.create_project_debrief!(
        what_worked: "The same classroom leaders served all week, which helped children settle quickly.",
        change_next_time: "Put snack carts together two days earlier."
      )

      maria = person("Maria Lopez")
      duplicate = ProjectDuplicate.new(source:, start_on: Date.current + 8.weeks, by: maria)
      duplicate.name = "Vacation Bible School #{Date.current.year}"
      vbs = duplicate.call
      vbs.update_columns(created_at: 3.months.ago, updated_at: 3.days.ago)
      projects[vbs.name] = vbs
      attach_banner!(vbs, "vbs-field.webp", "Children playing a group game on a sunny field.")
      invite!(vbs, "Elijah Brooks", "Maria Lopez", :leader, :accepted, 10.weeks.ago)
      invite!(vbs, "Naomi Patel", "Maria Lopez", :leader, :accepted, 10.weeks.ago)
      invite!(vbs, "Sam Chen", "Maria Lopez", :volunteer, :accepted, 9.weeks.ago)
      DemoOrganization::VBS_VOLUNTEER_NAMES.drop(1).each do |name|
        vbs.memberships.create!(person: person(name), role: :volunteer, created_at: 8.weeks.ago, updated_at: 8.weeks.ago)
      end
      {
        "Andrew Baker" => [ :volunteer, :pending ],
        "Rebecca Nelson" => [ :volunteer, :pending ],
        "Nathan Hill" => [ :volunteer, :pending ],
        "Jasmine Mitchell" => [ :leader, :pending ],
        "Samuel Roberts" => [ :volunteer, :declined ],
        "Luke Harris" => [ :volunteer, :declined ],
        "Danielle Walker" => [ :volunteer, :declined ],
        "Thomas Allen" => [ :volunteer, :pending ]
      }.each do |name, (role, status)|
        invite!(vbs, name, "Maria Lopez", role, status, 2.weeks.ago)
      end
      tasks = vbs.tasks.order(:id).to_a
      tasks.fetch(0).update!(assignee: person("Sam Chen"))
      complete_task!(tasks.fetch(1), "Tasha Williams", 2.weeks.ago)
      complete_task!(tasks.fetch(2), "Jonah Lee", 10.days.ago)
      claim!(vbs.slots.chronological.first, "Sam Chen", created_at: 1.week.ago)
    end

    def seed_workday!
      project = create_project!(
        name: "Church Workday",
        creator: "Grace Kim",
        description: "Work together on practical projects that care for our building and grounds.",
        starts_on: Date.current + 3.weeks,
        ends_on: Date.current + 3.weeks,
        created_at: 8.weeks.ago,
        skills: [ "Handyman", "Setup and teardown", "Gardening" ],
        tools: %w[tasks signup_sheet docs],
        photo: "workday.webp",
        alt: "Volunteers carrying tools during a church workday.",
        open_team: true
      )
      add_members!(project, {
        "Maria Lopez" => :leader,
        "Sam Chen" => :volunteer,
        "Esther Young" => :volunteer,
        "Ben Carter" => :volunteer,
        "Keisha Moore" => :volunteer,
        "Luke Harris" => :volunteer
      }, joined_at: 7.weeks.ago)
      add_tasks!(project, [
        [ "Wash exterior windows", nil, project.starts_on, false ],
        [ "Spread mulch by the playground", nil, project.starts_on, false ],
        [ "Touch up hallway paint", nil, project.starts_on, false ],
        [ "Sort the storage room", nil, project.starts_on, false ]
      ])
      add_slots!(project, [
        [ project.starts_on, "08:00", "Grounds crew", 4, [ "Sam Chen", "Esther Young" ] ],
        [ project.starts_on, "08:00", "Painting crew", 3, [ "Keisha Moore" ] ]
      ])
      document!(project, "Grace Kim", "Workday safety notes", "Wear closed-toe shoes and check in at the welcome table before starting a project.")
      link!(project, "Grace Kim", "Building map", "https://example.com/grace-fellowship/workday-map")
      file!(project, "Grace Kim", "Volunteer handbook")
    end

    def seed_mens_retreat!
      project = create_project!(
        name: "Men's Retreat",
        creator: "Maria Lopez",
        description: "A weekend of prayer, honest conversation, and time outdoors for the men of Grace Fellowship.",
        starts_on: Date.current + 10.weeks,
        ends_on: Date.current + 10.weeks + 2.days,
        created_at: 11.weeks.ago,
        skills: [ "Hospitality", "Driving", "Music" ],
        tools: %w[tasks schedule budget messages docs],
        photo: "mens-retreat.webp",
        alt: "Men gathered around a campfire at retreat."
      )
      add_members!(project, { "Sam Chen" => :volunteer, "Elijah Brooks" => :leader, "Marcus Reed" => :volunteer }, joined_at: 9.weeks.ago)
      add_tasks!(project, [
        [ "Confirm cabin assignments", "Elijah Brooks", project.starts_on - 14.days, false ],
        [ "Arrange carpools", "Sam Chen", project.starts_on - 7.days, false ],
        [ "Prepare discussion guides", "Maria Lopez", project.starts_on - 10.days, true ]
      ])
      add_schedule!(project, [
        [ project.starts_on, "18:30", "Dinner and welcome", "Camp dining hall" ],
        [ project.starts_on + 1.day, "08:30", "Morning prayer walk", "Trailhead" ],
        [ project.starts_on + 1.day, "19:00", "Campfire conversation", "Fire circle" ]
      ])
      add_budget!(project, [
        [ :booking, "Camp cabins", 310_000, nil, :reserved, "Maria Lopez" ],
        [ :purchase, "Meals and coffee", 72_000, 25_300, :reserved, "Elijah Brooks" ]
      ])
      root = message!(project, "Elijah Brooks", "Carpool seats are almost set. #{mention("Sam Chen")} can you confirm the last van?", 12.days.ago)
      message!(project, "Sam Chen", "Confirmed. The van has room for six plus luggage.", 11.days.ago, parent: root)
      comment!(root, "Maria Lopez", "Thank you both. #{mention("Daniel Okafor")} the transportation plan is settled.", 10.days.ago)
      document!(project, "Maria Lopez", "Retreat covenant", "Listen well, keep personal stories private, and make room for everyone to speak.")
    end

    def seed_kids_night!
      project = create_project!(
        name: "Kids' Night",
        creator: "Naomi Patel",
        description: "An evening of crafts, games, dinner, and Bible stories for elementary-age children.",
        starts_on: Date.current + 12.days,
        ends_on: Date.current + 12.days,
        created_at: 7.weeks.ago,
        skills: [ "Childcare", "Teaching", "Cooking" ],
        tools: %w[tasks schedule signup_sheet messages list],
        photo: "kids-crafts.webp",
        alt: "Children making colorful crafts together at a table.",
        open_team: true
      )
      add_members!(project, { "Sam Chen" => :volunteer, "Tasha Williams" => :volunteer, "Maya Thompson" => :volunteer }, joined_at: 6.weeks.ago)
      add_tasks!(project, [
        [ "Buy craft paper and washable paint", "Maya Thompson", project.starts_on - 5.days, true ],
        [ "Confirm allergy list", "Naomi Patel", project.starts_on - 3.days, false ],
        [ "Set up game stations", "Sam Chen", project.starts_on, false ]
      ])
      add_schedule!(project, [
        [ project.starts_on, "17:30", "Family check-in", "Lobby" ],
        [ project.starts_on, "18:00", "Dinner", "Fellowship Hall" ],
        [ project.starts_on, "18:40", "Crafts and games", "Children's wing" ]
      ])
      add_slots!(project, [
        [ project.starts_on, "17:15", "Check-in table", 2, [ "Tasha Williams" ] ],
        [ project.starts_on, "17:30", "Dinner crew", 3, [ "Sam Chen", "Maya Thompson" ] ]
      ])
      root = message!(project, "Naomi Patel", "The craft sample is on the planning table. #{mention("Daniel Okafor")} thanks for checking our room setup.", 9.days.ago)
      message!(project, "Maya Thompson", "Supplies are sorted by table and ready to go.", 8.days.ago, parent: root)
      comment!(root, "Sam Chen", "I can move the tables after lunch. #{mention("Maria Lopez")} the floor plan looks good.", 7.days.ago)
      add_list!(project, "Family check-in", [ "Household", "Forms complete" ], [
        [ "Bennett", true ],
        [ "Parker", true ],
        [ "Rivera", false ]
      ])
    end

    def seed_community_serve!
      project = create_project!(
        name: "Community Food Pantry Serve Day",
        creator: "Grace Kim",
        description: "Sort groceries, welcome neighbors, and pack family boxes for the community food pantry.",
        starts_on: Date.current + 4.weeks,
        ends_on: Date.current + 4.weeks,
        created_at: 5.weeks.ago,
        skills: [ "Hospitality", "Driving", "Setup and teardown" ],
        tools: %w[tasks signup_sheet budget recipients docs],
        photo: "community-serve.webp",
        alt: "Volunteers sorting groceries for a community food pantry.",
        open_team: true
      )
      add_members!(project, { "Maria Lopez" => :leader, "Sam Chen" => :volunteer, "Elijah Brooks" => :volunteer, "Aaron Price" => :volunteer }, joined_at: 4.weeks.ago)
      add_tasks!(project, [
        [ "Confirm pantry delivery count", "Maria Lopez", project.starts_on - 7.days, false ],
        [ "Label family box stations", "Sam Chen", project.starts_on - 1.day, false ],
        [ "Borrow two folding carts", "Aaron Price", project.starts_on - 3.days, true ]
      ])
      add_slots!(project, [
        [ project.starts_on, "08:00", "Grocery sorting", 4, [ "Maria Lopez", "Sam Chen" ] ],
        [ project.starts_on, "10:00", "Family box packing", 4, [ "Elijah Brooks", "Aaron Price" ] ]
      ])
      add_budget!(project, [
        [ :purchase, "Reusable grocery bags", 28_000, 26_400, :paid, "Maria Lopez" ],
        [ :purchase, "Box labels and markers", 6_500, 5_980, :paid, "Sam Chen" ]
      ])
      add_recipient!(project, "Rachel Hernandez", [
        [ "Maria Lopez", :team, "Prefers a text before the delivery window" ],
        [ "Grace Kim", :leaders, "Please include the low-sodium pantry list" ]
      ])
      document!(project, "Grace Kim", "Pantry welcome guide", "Greet each household by name, explain what is in the box, and offer help carrying it.")
      project.enable_public_link!
    end

    def seed_welcome_team!
      sundays = 4.times.map { |index| Date.current.next_occurring(:sunday) + index.weeks }
      project = create_project!(
        name: "Sunday Welcome & Coffee Team",
        creator: "Owen Parker",
        description: "Welcome people at the doors and keep coffee ready before Sunday worship.",
        starts_on: sundays.first,
        ends_on: sundays.last,
        created_at: 6.weeks.ago,
        skills: [ "Hospitality", "Cooking" ],
        tools: %w[tasks signup_sheet messages],
        photo: "kitchen-crew.webp",
        alt: "Volunteers preparing coffee together in the church kitchen.",
        open_team: true
      )
      add_members!(project, {
        "Priya Shah" => :volunteer,
        "Chloe Martin" => :volunteer,
        "Noah Davis" => :volunteer
      }, joined_at: 5.weeks.ago)
      add_tasks!(project, [
        [ "Restock cups and coffee", "Priya Shah", Date.current + 2.days, false ],
        [ "Print the welcome desk name tags", "Chloe Martin", Date.current + 5.days, false ]
      ])
      sundays.each_with_index do |date, index|
        claims = index.zero? ? [ "Owen Parker", "Priya Shah" ] : []
        add_slots!(project, [ [ date, "08:30", "Welcome doors", 3, claims ] ])
      end
      add_slots!(project, [
        [ sundays.first, "08:00", "Coffee setup", 4, [ "Chloe Martin", "Noah Davis", "Priya Shah" ] ],
        [ sundays.second, "08:00", "Coffee setup", 4, [ "Noah Davis" ] ]
      ])
      root = message!(project, "Owen Parker", "The new coffee station signs are ready for Sunday.", 5.days.ago)
      message!(project, "Priya Shah", "I will bring the extra airpots and set them out early.", 4.days.ago, parent: root)
      comment!(root, "Chloe Martin", "Name tags are printed and waiting at the welcome desk.", 3.days.ago)
    end

    def seed_thanksgiving_baskets!
      project = create_project!(
        name: "Thanksgiving Baskets",
        creator: "Lydia Evans",
        description: "Pack pantry staples and deliver Thanksgiving baskets to families around Grace Fellowship.",
        starts_on: Date.current + 10.days,
        ends_on: Date.current + 16.days,
        created_at: 5.weeks.ago,
        skills: [ "Driving", "Hospitality", "Setup and teardown" ],
        tools: %w[tasks signup_sheet messages],
        photo: "planning-table.webp",
        alt: "Volunteers planning together around a table.",
        open_team: true
      )
      add_members!(project, {
        "Josiah Clark" => :volunteer,
        "Miriam Wright" => :volunteer,
        "Esther Young" => :volunteer
      }, joined_at: 4.weeks.ago)
      add_tasks!(project, [
        [ "Confirm the basket shopping list", "Lydia Evans", Date.current + 3.days, false ],
        [ "Call delivery households", "Miriam Wright", Date.current + 6.days, false ],
        [ "Label delivery routes", "Josiah Clark", project.starts_on - 1.day, false ]
      ])
      add_slots!(project, [
        [ project.starts_on, "09:00", "Basket packing", 6, [ "Lydia Evans", "Josiah Clark", "Miriam Wright", "Esther Young", "Aaron Price" ] ],
        [ project.starts_on + 2.days, "10:00", "Basket delivery", 8, [ "Lydia Evans", "Esther Young" ] ],
        [ project.ends_on, "17:00", "Follow-up calls", 4, [] ]
      ])
      root = message!(project, "Lydia Evans", "The family list is final. We are packing twenty-four baskets this year.", 4.days.ago)
      message!(project, "Josiah Clark", "I split the deliveries into four routes and added drive times.", 3.days.ago, parent: root)
      comment!(root, "Miriam Wright", "I can call each household the day before delivery.", 2.days.ago)
    end

    def seed_parking_team!
      project = create_project!(
        name: "Parking & Arrival Team",
        creator: "Isaac Rivera",
        description: "Help guests find parking and make the walk from the lot feel welcoming.",
        starts_on: Date.current + 2.weeks,
        ends_on: Date.current + 2.weeks,
        created_at: 4.weeks.ago,
        skills: [ "Hospitality", "Setup and teardown" ],
        tools: %w[tasks signup_sheet messages],
        photo: nil,
        alt: nil,
        open_team: true
      )
      add_members!(project, {
        "Lucas Martinez" => :volunteer,
        "Zoe Campbell" => :volunteer,
        "Ethan Wilson" => :volunteer
      }, joined_at: 3.weeks.ago)
      add_tasks!(project, [
        [ "Set out parking signs", "Isaac Rivera", Date.current + 4.days, false ],
        [ "Check radios and umbrellas", "Lucas Martinez", Date.current + 6.days, false ]
      ])
      add_slots!(project, [
        [ project.starts_on, "08:15", "Parking guides", 6, [ "Isaac Rivera", "Ethan Wilson" ] ],
        [ project.starts_on, "08:30", "Front walk welcome", 4, [ "Lucas Martinez", "Zoe Campbell", "Isaac Rivera" ] ]
      ])
      root = message!(project, "Isaac Rivera", "Rain is possible, so the umbrellas will be beside the radio chargers.", 3.days.ago)
      message!(project, "Zoe Campbell", "I checked the umbrellas and replaced two broken ones.", 2.days.ago, parent: root)
      comment!(root, "Isaac Rivera", "The parking signs are stacked by the east doors.", 1.day.ago)
    end

    def seed_finished_projects!
      seed_finished_mens_retreat!
      seed_finished_workday!
      seed_finished_meal_train!
      seed_finished_christmas_outreach!
      seed_finished_kids_night!
    end

    def seed_finished_mens_retreat!
      finish = 11.months.ago.to_date
      project = finished_project!("Men's Retreat #{Date.current.year - 1}", "Elijah Brooks", finish - 2.days, finish, "mens-retreat.webp",
        "Men gathered around a campfire at retreat.", [ "Maria Lopez", "Sam Chen", "Marcus Reed" ])
      document!(project, "Elijah Brooks", "Cabin checkout notes", "Sweep cabins, return keys, and bring leftover food to the kitchen before departure.")
    end

    def seed_finished_workday!
      finish = 7.months.ago.to_date
      project = finished_project!("Spring Church Workday", "Grace Kim", finish, finish, "setup-crew.webp",
        "Volunteers setting up tables during a church workday.", [ "Maria Lopez", "Sam Chen", "Esther Young" ])
      file!(project, "Grace Kim", "Spring volunteer handbook")
    end

    def seed_finished_meal_train!
      finish = 9.months.ago.to_date
      project = finished_project!("Meal Train for the Hernandez Family", "Maria Lopez", finish - 3.weeks, finish, "meal-train-porch.webp",
        "A prepared meal waiting on a front porch.", [ "Grace Kim", "Ruth Bennett", "Lydia Evans" ], tools: %w[tasks signup_sheet budget recipients messages])
      add_recipient!(project, "Rachel Hernandez", [
        [ "Maria Lopez", :team, "No shellfish; meals can be left in the porch cooler" ],
        [ "Grace Kim", :leaders, "A grocery card was included with the final delivery" ]
      ])
      root = message!(project, "Maria Lopez", "Every dinner is covered through Friday. Thank you for serving so faithfully.", finish - 4.weeks)
      message!(project, "Ruth Bennett", "Friday's soup is labeled and in the church refrigerator.", finish - 25.days, parent: root)
    end

    def seed_finished_christmas_outreach!
      finish = Date.new(Date.current.year - 1, 12, 21)
      finished_project!("Christmas Outreach #{Date.current.year - 1}", "Maria Lopez", finish - 2.days, finish, "kitchen-crew.webp",
        "Volunteers preparing food together in a church kitchen.", [ "Grace Kim", "Sam Chen", "Keisha Moore" ], tools: %w[tasks schedule signup_sheet budget messages])
    end

    def seed_finished_kids_night!
      finish = 4.months.ago.to_date
      project = finished_project!("Summer Kids' Night", "Naomi Patel", finish, finish, "kids-crafts.webp",
        "Children making colorful crafts together at a table.", [ "Sam Chen", "Tasha Williams", "Maya Thompson" ], tools: %w[tasks schedule signup_sheet budget list])
      add_list!(project, "Supply bins", [ "Station", "Returned" ], [ [ "Crafts", true ], [ "Games", true ], [ "Dinner", true ] ])
    end

    def finished_project!(name, creator, starts_on, done_on, photo, alt, members, tools: %w[tasks schedule signup_sheet budget])
      project = create_project!(
        name:,
        creator:,
        description: "A completed ministry project preserved with its plans, costs, and serving history.",
        starts_on:,
        ends_on: done_on,
        created_at: starts_on - 2.months,
        done_at: Time.zone.local(done_on.year, done_on.month, done_on.day, 18),
        skills: [ "Hospitality", "Setup and teardown" ],
        tools:,
        photo:,
        alt:
      )
      add_members!(project, members.index_with { :volunteer }, joined_at: starts_on - 6.weeks)
      add_tasks!(project, [
        [ "Confirm the Team plan", creator, starts_on - 14.days, true ],
        [ "Prepare supplies", members.first, starts_on - 3.days, true ],
        [ "Return borrowed equipment", members.second, done_on, true ]
      ])
      add_schedule!(project, [
        [ starts_on, "09:00", "Team huddle", "Fellowship Hall" ],
        [ done_on, "16:30", "Cleanup and prayer", "Fellowship Hall" ]
      ]) if tools.include?("schedule")
      add_slots!(project, [
        [ starts_on, "08:30", "Setup crew", 2, members.first(2) ],
        [ done_on, "16:00", "Cleanup crew", 2, members.drop(1).first(2) ]
      ])
      add_budget!(project, [
        [ :purchase, "Project supplies", 32_000, 30_475, :paid, creator ],
        [ :purchase, "Team meal", 18_000, 17_820, :paid, members.first ]
      ])
      if tools.include?("messages") && project.messages.none?
        root = message!(project, creator, "Everything is covered. Please arrive fifteen minutes before the Team huddle.", starts_on - 5.days)
        message!(project, members.first, "I can bring the extra folding cart.", starts_on - 4.days, parent: root)
      end
      project.create_project_debrief!(
        what_worked: "Leaders named responsibilities early and the Team finished cleanup together.",
        change_next_time: "Confirm supply quantities one week earlier."
      )
      project
    end

    def seed_people_history!
      [
        [ "Sam Chen", "Daniel Okafor", 12.days.ago.to_date, "Serving rhythm is healthy; asked for one quiet weekend next month." ],
        [ "Maria Lopez", "Daniel Okafor", 5.weeks.ago.to_date, "Reviewed the fall calendar and delegated two follow-ups." ],
        [ "Grace Kim", "Daniel Okafor", 3.months.ago.to_date, "Retreat planning is on track and the Team is responding well." ],
        [ "Ruth Bennett", "Maria Lopez", 5.months.ago.to_date, "Meal deliveries are a good fit for her current schedule." ],
        [ "Elijah Brooks", "Daniel Okafor", 8.months.ago.to_date, "Enjoyed leading VBS and wants to mentor a new Leader." ],
        [ "Tasha Williams", "Maria Lopez", 11.months.ago.to_date, "Appreciated being asked before the holiday rush." ]
      ].each do |name, checker, on, note|
        CheckIn.create!(organization:, person: person(name), checked_in_by: person(checker), on:, note:, created_at: on.noon, updated_at: on.noon)
      end

      [
        [ "Tasha Williams", Date.current - 2.days, Date.current + 5.days, "Family visit" ],
        [ "Elijah Brooks", Date.current - 1.day, Date.current + 3.days, "Traveling" ],
        [ "Ruth Bennett", Date.current + 3.weeks, Date.current + 4.weeks, "Out of town" ]
      ].each do |name, starts_on, ends_on, note|
        Unavailability.create!(organization:, person: person(name), starts_on:, ends_on:, note:, created_at: 1.month.ago, updated_at: 1.month.ago)
      end

      person("Sam Chen").notes.create!(organization:, author: person("Daniel Okafor"), body: "Prefers hands-on serving roles and early setup times.", created_at: 2.months.ago, updated_at: 2.months.ago)
      person("Maria Lopez").notes.create!(organization:, author: person("Daniel Okafor"), body: "Follow up after the fall calendar settles.", created_at: 4.months.ago, updated_at: 4.months.ago)

      ensure_role_notifications!
    end

    def ensure_role_notifications!
      targets = {
        "Daniel Okafor" => projects.fetch("Thanksgiving Baskets"),
        "Maria Lopez" => projects.fetch("Sunday Welcome & Coffee Team"),
        "Sam Chen" => projects.fetch("Parking & Arrival Team")
      }
      targets.each do |name, project|
        authors = project.people.where.not(id: person(name).id).order(:id).first(2)
        2.times do |index|
          actor = authors.fetch(index)
          root = message!(project, actor.name, "#{mention(name)} please review this Team update when you have a moment.", (index + 1).days.ago)
          root.update_columns(created_at: (index + 1).days.ago, updated_at: (index + 1).days.ago)
        end
      end
    end

    def create_project!(name:, creator:, description:, starts_on:, ends_on:, created_at:, skills:, tools:, photo:, alt:, done_at: nil, open_team: false)
      project = Project.create_for(
        creator: person(creator),
        attributes: {
          name:,
          description:,
          starts_on:,
          ends_on:,
          created_at:,
          updated_at: created_at,
          done_at:,
          open_team:,
          skills_needed: skills,
          enabled_tools: tools
        }
      )
      projects[name] = project
      project.memberships.update_all(created_at:, updated_at: created_at)
      attach_banner!(project, photo, alt) if photo
      project
    end

    def add_public_helpers!(project)
      [
        [ "Nadia Brooks", "+12025552001", 4 ],
        [ "Tom Ellison", "+12025552002", 6 ],
        [ "Evelyn Price", "+12025552003", 8 ],
        [ "Jordan Bell", "+12025552004", 10 ]
      ].each_with_index do |(name, phone, day_offset), index|
        helper = organization.people.create!(name:, phone:, joined_from_project: project)
        slot = project.slots.find_by!(date: Date.current + day_offset)
        claim = slot.claim(helper)
        raise ActiveRecord::RecordInvalid, claim unless claim&.persisted?

        claim.update_columns(created_at: (4 - index).days.ago, updated_at: (4 - index).days.ago)
      end
    end

    def attach_banner!(project, filename, alt)
      path = PHOTO_ROOT.join(filename)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: path.open,
        filename:,
        content_type: "image/webp",
        metadata: { "organization_id" => organization.id }
      )
      blob.analyze
      project.banner.attach(blob)
      project.update!(banner_alt_text: alt, banner_focus_manual: true)
    end

    def add_members!(project, members, joined_at:)
      members.each do |name, role|
        next if project.memberships.exists?(person: person(name))

        project.memberships.create!(person: person(name), role:, created_at: joined_at, updated_at: joined_at)
      end
    end

    def invite!(project, name, inviter, role, status, created_at)
      invitation = organization.invitations.create!(
        project:,
        person: person(name),
        inviter: person(inviter),
        role:,
        created_at:,
        updated_at: created_at
      )
      invitation.accept! if status == :accepted
      invitation.decline! if status == :declined
      invitation.update_columns(
        created_at:,
        updated_at: status == :pending ? created_at : created_at + 2.days,
        responded_at: status == :pending ? nil : created_at + 2.days
      )
      project.memberships.find_by(person: person(name))&.update_columns(created_at:, updated_at: created_at)
      invitation
    end

    def add_tasks!(project, rows)
      rows.each_with_index do |(title, assignee, due_on, done), index|
        task = project.tasks.create!(title:, due_on:, assignee: assignee && person(assignee), created_at: project.created_at + index.days, updated_at: project.created_at + index.days)
        complete_task!(task, assignee || project.owner.name, due_on.to_time.in_time_zone - 1.day) if done
      end
    end

    def complete_task!(task, name, completed_at)
      task.update!(completed_by: person(name), completed_at:, updated_at: completed_at)
    end

    def add_schedule!(project, rows)
      rows.each do |date, time, title, location|
        project.schedule_items.create!(date:, starts_at_time: time, title:, location:, created_at: project.created_at + 1.day, updated_at: project.created_at + 1.day)
      end
    end

    def add_daily_slots!(project, start_date, end_date, label, time, capacity)
      run = SlotRun.new(project:, start_date:, end_date:, starts_at_time: time, label:, capacity:)
      raise ActiveModel::ValidationError, run unless run.save

      project.slots.update_all(created_at: project.created_at + 2.days, updated_at: project.created_at + 2.days)
    end

    def add_slots!(project, rows)
      rows.each do |date, time, label, capacity, names|
        slot = project.slots.create!(date:, starts_at_time: time, label:, capacity:, created_at: project.created_at + 2.days, updated_at: project.created_at + 2.days)
        names.each { |name| claim!(slot, name, created_at: project.created_at + 3.days) }
      end
    end

    def claim!(slot, name, created_at:, note: nil)
      claim = if slot.date < Date.current
        slot.slot_claims.create(person: person(name), note:)
      else
        slot.claim(person(name), note:)
      end
      raise ActiveRecord::RecordInvalid, claim unless claim&.persisted?

      claim.update_columns(created_at:, updated_at: created_at)
    end

    def add_budget!(project, rows)
      rows.each do |kind, description, estimated, actual, status, responsible|
        project.budget_lines.create!(
          kind:,
          description:,
          estimated_cents: estimated,
          actual_cents: actual,
          status:,
          responsible_person: person(responsible),
          created_at: project.created_at + 1.week,
          updated_at: project.created_at + 1.week
        )
      end
    end

    def add_recipient!(project, name, notes)
      recipient = project.recipients.create!(person: person(name), created_at: project.created_at + 1.day, updated_at: project.created_at + 1.day)
      notes.each_with_index do |(author, visibility, body), index|
        recipient.notes.create!(organization:, author: person(author), visibility:, body:, created_at: project.created_at + (index + 2).days, updated_at: project.created_at + (index + 2).days)
      end
      recipient
    end

    def message!(project, author, body, created_at, parent: nil)
      project.messages.create!(author: person(author), body:, parent:, created_at:, updated_at: created_at)
    end

    def comment!(commentable, author, body, created_at)
      commentable.comments.create!(author: person(author), body:, created_at:, updated_at: created_at)
    end

    def document!(project, author, title, body)
      project.doc_items.create!(author: person(author), kind: :document, title:, body:, created_at: project.created_at + 1.week, updated_at: project.created_at + 1.week)
    end

    def link!(project, author, title, url)
      project.doc_items.create!(author: person(author), kind: :link, title:, url:, created_at: project.created_at + 1.week, updated_at: project.created_at + 1.week)
    end

    def file!(project, author, title)
      item = project.doc_items.build(author: person(author), kind: :file, title:, created_at: project.created_at + 1.week, updated_at: project.created_at + 1.week)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: HANDBOOK_PATH.open,
        filename: "volunteer-handbook.pdf",
        content_type: "application/pdf",
        metadata: { "organization_id" => organization.id }
      )
      item.file.attach(blob)
      item.save!
    end

    def add_list!(project, name, columns, rows)
      list = project.lists.create!(name:, created_at: project.created_at + 1.week, updated_at: project.created_at + 1.week)
      list_columns = columns.map do |column|
        type = column.match?(/Ready|Packed|complete|Returned/i) ? :checkbox : :text
        list.columns.create!(name: column, column_type: type, created_at: list.created_at, updated_at: list.created_at)
      end
      rows.each do |values|
        cells = list_columns.zip(values).to_h { |column, value| [ column.id.to_s, value ] }
        list.rows.create!(cells:, created_at: list.created_at + 1.day, updated_at: list.created_at + 1.day)
      end
      list
    end

    def mention(name)
      target = person(name)
      "@[#{target.name}](person:#{target.id})"
    end

    def person(name)
      people.fetch(name)
    end
end
