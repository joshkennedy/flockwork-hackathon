# Rails 8 and Hotwire, without React

Flockwork is a Rails 8 app using Hotwire (Turbo and Stimulus) for interactivity, Postgres, `ruby_llm` with Claude for the Planner, Active Storage on R2 or S3, and Railway for hosting. Rails ships the rich text, file uploads, background jobs, live updates and email that the Tools need, which Go or Rust would have us build by hand inside a four-week hackathon, and earlier attempts at React inside Rails were slow to work in. React is allowed only for a small, purposeful island that Hotwire genuinely can't handle.
