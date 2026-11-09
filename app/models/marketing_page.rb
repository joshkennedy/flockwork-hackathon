MarketingPage = Data.define(:slug, :label, :title, :description, :summary, :section, :nav, :scene, :photo) do
  const_set(:ALL, [
    new(
      slug: "",
      label: "Home",
      title: "Flockwork · Project planning for your church",
      description: "Project planning for your church. Meal trains, VBS, workdays, retreats: Flockwork makes them easier to plan and simpler to fill, so you can say yes to more of them.",
      summary: "Plan church projects in one place so members can serve each other and their community.",
      section: :product,
      nav: false,
      scene: "hero",
      photo: nil
    ),
    new(
      slug: "features",
      label: "Features",
      title: "Church project features · Flockwork",
      description: "Keep sign-ups, tasks, schedules, budgets and people together, so church projects are easier to run and simpler to serve through.",
      summary: "See the tools that keep a church project organized from first plan to final task.",
      section: :product,
      nav: true,
      scene: nil,
      photo: "community-serve"
    ),
    new(
      slug: "features/sign-ups",
      label: "Sign-up sheets",
      title: "Volunteer sign-up sheets · Flockwork",
      description: "Share one sign-up link, show the spots still open and help church members choose a practical way to serve from any phone.",
      summary: "Share a clear sign-up sheet that shows volunteers which spots still need someone.",
      section: :feature,
      nav: false,
      scene: "tour-signup",
      photo: "phone-yes"
    ),
    new(
      slug: "features/tasks",
      label: "Tasks",
      title: "Church project tasks · Flockwork",
      description: "Keep project tasks and owners visible in one place, so the work moves forward and church members know how they can help.",
      summary: "Track project tasks and who owns them without losing the work in separate lists.",
      section: :feature,
      nav: false,
      scene: "tour-tasks",
      photo: "workday"
    ),
    new(
      slug: "features/schedule",
      label: "Schedule",
      title: "Church project schedules · Flockwork",
      description: "Build the run of a church project in one shared schedule, so leaders stay coordinated and volunteers know what happens next.",
      summary: "Put the run of the day in one schedule that leaders and volunteers can follow.",
      section: :feature,
      nav: false,
      scene: "tour-schedule",
      photo: "kids-crafts"
    ),
    new(
      slug: "features/budget",
      label: "Budget",
      title: "Church project budgets · Flockwork",
      description: "Track estimated and actual project costs beside the work, so leaders can steward resources while people focus on serving.",
      summary: "Track estimated and actual costs alongside the church project they support.",
      section: :feature,
      nav: false,
      scene: "tour-budget",
      photo: "kitchen-crew"
    ),
    new(
      slug: "features/planner",
      label: "Planner",
      title: "AI church project planner · Flockwork",
      description: "Describe a church project, answer a few questions and review a practical plan that helps your people get ready to serve.",
      summary: "Turn a project description and a few answers into suggestions you review before adding.",
      section: :feature,
      nav: false,
      scene: "tour-planner",
      photo: "vbs-field"
    ),
    new(
      slug: "features/people",
      label: "People",
      title: "Church people directory · Flockwork",
      description: "Bring your church directory in from Planning Center or a CSV, then find people and skills that can support each project.",
      summary: "Bring in your people and find the skills a church project needs.",
      section: :feature,
      nav: false,
      scene: "card-people",
      photo: "womens-retreat"
    ),
    new(
      slug: "features/oversight",
      label: "Oversight",
      title: "Church volunteer oversight · Flockwork",
      description: "See who is serving, away or carrying too many projects, so leaders can share the work with greater care for their people.",
      summary: "See serving load and time away before asking the same people to carry more.",
      section: :feature,
      nav: false,
      scene: "card-oversight",
      photo: "mens-retreat"
    ),
    new(
      slug: "pricing",
      label: "Pricing",
      title: "Pricing · Flockwork",
      description: "Use every Flockwork project planning tool free during beta, with no card required and notice before pricing changes.",
      summary: "Flockwork is free during beta, with every project planning tool included.",
      section: :product,
      nav: true,
      scene: nil,
      photo: "planning-table"
    ),
    new(
      slug: "about",
      label: "About",
      title: "About Flockwork",
      description: "Learn why Outpost Labs LLC built Flockwork in Tennessee to make church projects easier to organize and service easier to share.",
      summary: "Why Flockwork exists and who builds it for churches and their people.",
      section: :company,
      nav: false,
      scene: nil,
      photo: "meal-train-door"
    ),
    new(
      slug: "contact",
      label: "Contact",
      title: "Contact Flockwork",
      description: "Contact Flockwork with product questions, requests about your church's data or security reports at hello@getflockwork.com.",
      summary: "Write to Flockwork about the product, church data requests or security reports.",
      section: :company,
      nav: false,
      scene: nil,
      photo: "setup-crew"
    ),
    new(
      slug: "terms",
      label: "Terms",
      title: "Terms · Flockwork",
      description: "Read the terms for using Flockwork to plan church projects, coordinate volunteers and review AI-generated suggestions.",
      summary: "Terms for using Flockwork and reviewing its planning suggestions.",
      section: :legal,
      nav: false,
      scene: nil,
      photo: nil
    ),
    new(
      slug: "privacy",
      label: "Privacy policy",
      title: "Privacy policy · Flockwork",
      description: "Learn what Flockwork stores and what text planning, voice planning and browser dictation send to outside services.",
      summary: "How Flockwork stores workspace data and handles text and voice planning.",
      section: :legal,
      nav: false,
      scene: nil,
      photo: nil
    )
  ].freeze)

  def self.find(slug)
    const_get(:ALL).find { |page| page.slug == slug }
  end

  def self.in_section(section)
    const_get(:ALL).select { |page| page.section == section }
  end

  def path
    home? ? "/" : "/#{slug}"
  end

  def template
    slug.tr("-", "_") unless home?
  end

  def route_name
    slug.tr("/-", "__").to_sym
  end

  def home?
    slug.empty?
  end
end
