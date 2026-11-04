# Flockwork

Entry for **AI for Church Hackathon 2026** (Church Operations & Admin track). Flockwork is “Basecamp for churches”: each church gets a **Organization** with a **People** directory and **Projects** built from a fixed set of **Tools**—Tasks, Schedule, Sign-up sheet, Budget, Recipients, Messages, Docs & Files, and List. Leaders run an **AI Planner** to shape a Project; **Oversight** helps Admins see serving load and who still needs an invitation. The Planner is designed so it sees the work, not the people: it never receives directory data, names, or care details ([docs/adr/0002-the-ai-never-sees-people.md](docs/adr/0002-the-ai-never-sees-people.md)).

## Try it

After setup, open [http://localhost:3000/grace-fellowship/sign_in](http://localhost:3000/grace-fellowship/sign_in). The demo Organization **Grace Fellowship** is seeded from `DemoOrganization` on `db:prepare` / `db:seed`.

Three buttons sign you in as fixed synthetic People (no email link needed):

| Button | Person | What you see |
|--------|--------|--------------|
| Explore as Admin | Daniel Okafor | Full Organization: **People** (directory, CSV import, Planning Center sync), **Oversight** (overextended limit, never asked, involvement by year), and every Project |
| Explore as Leader | Maria Lopez | Projects Maria leads or belongs to (retreat, meal train, VBS, workday, and duplicates)—including **Planner**, Team management, and Tools she can manage |
| Explore as Volunteer | Sam Chen | Home, **My Tasks**, Projects Sam is on (for example VBS), **Get involved**, and open-team Projects—no People or Oversight |

Non-demo Organizations use email magic links only; the Explore buttons appear when `organization.demo?` is true.

## How the AI Planner works

1. A Leader opens **Planner** on a Project, writes **one sentence** (`PlannerSession#description`), and submits **Start planning**.
2. Each turn, `Planner::ContextBuilder` is the only code that calls the model (via `Rails.configuration.x.planner_provider`). The model returns one question card (3–5 options) or `finished: true`.
3. Answers enqueue `PlannerStepJob` (Solid Queue). New items arrive as **Suggestions** with status `proposed`—shown as ghost tiles in the live summary until the Leader taps **Keep** or **Drop** right there (or **Edit** on the review screen). Kept Suggestions turn solid.
4. **Accept** writes kept/edited (and optionally remaining proposed) Suggestions into real Project records through `Planner::SuggestionKinds`.

**Provider:** `Planner::Providers::Llm` uses RubyLLM with provider `PLANNER_LLM_PROVIDER` (default `openrouter`) and model `PLANNER_LLM_MODEL` (default `anthropic/claude-sonnet-5.5`). Set `OPENROUTER_API_KEY` in `.env.development.local` (see setup).

**Delta contract:** each response includes `added` (new Suggestions only) and `removed_ids` (ids to drop from `current_suggestions`). `PlannerSession#apply_response!` skips removals for Suggestions already **kept** or **edited**—Leader decisions win over the model.

Tests stub the provider with `Planner::Providers::Fake` and assert no Person name, email, or phone appears in the JSON sent to the provider.

## Stack

- **Rails 8.1** + Hotwire (Turbo, Stimulus), importmap, Propshaft
- **Ruby 4.0.9** (see `.ruby-version`; use [mise](https://mise.jdx.dev/) locally)
- **PostgreSQL**; **Solid Queue**, **Solid Cache**, **Solid Cable** (database-backed)
- **Action Text**, **Active Storage** (variants via `image_processing`)
- **Tailwind CSS v4** (`tailwindcss-rails`, tokens in `app/assets/tailwind/application.css`, spec in [DESIGN.md](DESIGN.md))
- **ruby_llm** 2.1.1 for the Planner ([config/initializers/ruby_llm.rb](config/initializers/ruby_llm.rb))
- **Fonts:** Mattone (display/wordmark, SIL OFL—[app/assets/fonts/Mattone-OFL.txt](app/assets/fonts/Mattone-OFL.txt)) and Mona Sans (UI), loaded via [app/assets/stylesheets/fonts.css](app/assets/stylesheets/fonts.css)

## Local setup

**Prerequisites**

- mise (or another Ruby version manager matching `.ruby-version`)
- PostgreSQL running locally for development
- Docker running for the test suite (Testcontainers Postgres)
- Node.js for system tests (`npm ci`, Playwright Chromium)

**Quick path**

```bash
bin/setup --skip-server   # bundle, db:prepare (loads db/seeds.rb → DemoOrganization), clear tmp
```

**Manual path**

```bash
bundle install
bin/rails db:prepare      # creates DB and runs seeds
```

**Environment** (gitignored `.env*`; dotenv loads in development/test)

Create `.env.development.local`:

| Variable | Purpose |
|----------|---------|
| `OPENROUTER_API_KEY` | Planner in development (required for live AI) |
| `PCO_APP_ID`, `PCO_SECRET` | Optional Planning Center People import (`DirectorySources::PlanningCenter`) |
| `SENDLY_SANDBOX_API_KEY` | Optional Sendly SMS sandbox client. See [Sendly setup](docs/sendly.md). |

For production SMS notifications, set `SENDLY_API_KEY` and run the Solid Queue
worker. People choose their notification channels in **My profile > Notifications**;
SMS stays off until they enable it. See [production SMS setup](docs/sendly.md#enable-production-sending).

`config/credentials/development.key` is gitignored; ask a maintainer for the key if encrypted credentials are required locally.

**Run**

```bash
SOLID_QUEUE_IN_PUMA=1 bin/dev
```

`Procfile.dev` runs Puma plus Tailwind watch. `SOLID_QUEUE_IN_PUMA=1` runs the Solid Queue worker inside Puma so `PlannerStepJob` can fetch the next question card after each answer.

Without foreman:

```bash
bin/rails tailwindcss:build && SOLID_QUEUE_IN_PUMA=1 bin/rails server
```

## Tests and quality

```bash
bin/rails test              # Docker must be running (Testcontainers Postgres in test/test_helper.rb)
bin/rails test:system       # after: npm ci && npx playwright install chromium
bin/rubocop
bin/brakeman
```

CI (`bin/ci`) runs setup, RuboCop, bundler-audit, importmap audit, Brakeman, and `bin/rails test`.

**Planner privacy tests:** integration tests build an organization full of distinctive Person names/emails/phones and assert `Planner::ContextBuilder` output never includes them (ADR 0002).

**Planning Center:** integration tests use VCR cassettes recorded against a synthetic sandbox org. Re-record with `VCR_RECORD=1` (loads `.env.development.local` in [test/support/vcr.rb](test/support/vcr.rb)). Seed the sandbox with `PCO_SANDBOX=1 bin/rails pco:seed_sandbox` (requires `PCO_APP_ID` / `PCO_SECRET`).

## Project layout

| Area | Location |
|------|----------|
| Authorization | [app/policies/policy.rb](app/policies/policy.rb) (`Policy.can?`, `visible_notes`, project visibility) |
| Oversight queries | [app/models/oversight.rb](app/models/oversight.rb) |
| Planner domain | [app/models/planner_session.rb](app/models/planner_session.rb), [app/models/planner/](app/models/planner/), [app/controllers/planner_sessions_controller.rb](app/controllers/planner_sessions_controller.rb) |
| Directory import | [app/models/directory_sources/](app/models/directory_sources/) (Planning Center + base) |
| Duplicate Project | [app/models/project_duplicate.rb](app/models/project_duplicate.rb) |
| Design tokens | [app/assets/tailwind/application.css](app/assets/tailwind/application.css) (companion spec: [DESIGN.md](DESIGN.md)) |
| Demo seed | [app/models/demo_organization.rb](app/models/demo_organization.rb), [db/seeds.rb](db/seeds.rb) |

## Docs

- [DESIGN.md](DESIGN.md) — visual system (colors, type, components)
- [docs/adr/](docs/adr/) — architecture decisions (toolkit, AI privacy, Rails/Hotwire)
- [docs/GLOSSARY.md](docs/GLOSSARY.md) — product language (Organization, Project, Tool, Planner, Oversight, etc.)

## Data and privacy

- Grace Fellowship and all demo People are **synthetic**; no real congregant data ships in the repo.
- API keys and credentials stay in env vars or Rails credentials—never committed (see `.gitignore`).
- **Notes** use visibility enums; `Policy.visible_notes` filters what each role can load in SQL (Person notes are always Admins-only). The Planner context builder does not include Note bodies or Person records.
