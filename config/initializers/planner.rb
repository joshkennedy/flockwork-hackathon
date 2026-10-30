Rails.application.config.after_initialize do
  Rails.configuration.x.planner_provider = if Rails.env.test?
    Planner::Providers::Fake.new([
      Planner::Response.new(
        card: {
          "question" => "What should this Project accomplish first?",
          "options" => [ "Prepare the space", "Gather supplies", "Welcome the Team" ]
        },
        finished: false,
        suggestions: []
      )
    ])
  else
    Planner::Providers::Claude.new
  end
end
