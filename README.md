# Flockwork

Entry for **AI for Church Hackathon 2026** (Church Operations & Admin track). Flockwork is “Basecamp for churches”: each church gets an **Organization** with a **People** directory and **Projects** built from **Tools**. The Grace Fellowship demo shows all eight: Tasks, Schedule, Sign-up sheet, Budget, Recipients, Messages, Docs & Files, and List. Leaders run an **AI Planner** to shape a Project; **Oversight** helps Admins and Leaders see serving load and who still needs an invitation. The Planner is designed so it sees the work, not the people: it never receives directory data, names, or care details ([docs/adr/0002-the-ai-never-sees-people.md](docs/adr/0002-the-ai-never-sees-people.md)).

**Live demo:** [getflockwork.com/demo](https://getflockwork.com/demo). No account needed.

**Built in the hackathon window.** The first commit is the empty Rails app on 2026-10-30, the day the build window opened; everything in this repository was written between then and the 2026-11-27 deadline, with Claude and Codex as coding agents.

## Try it

Open [getflockwork.com/demo](https://getflockwork.com/demo), or [localhost:3000/demo](http://localhost:3000/demo) after local setup. The demo church **Grace Fellowship** is synthetic, seeded from `DemoOrganization`, and resets every hour. Demo People never receive email or texts, and the demo's AI use is capped.

Three buttons on `/demo` sign you in as fixed synthetic People (no email link needed):

| Button | Person | What you see |
|--------|--------|--------------|
| Explore as Admin | Daniel Okafor | Every Project, **People** (directory, CSV import, Planning Center sync), **Oversight**, and Organization settings, including the overextended limit |
| Explore as Leader | Maria Lopez | Projects Maria leads or belongs to, **Planner**, Team management, Project Tools, and read-only **Oversight** |
| Explore as Volunteer | Sam Chen | Home, **My Tasks**, Projects Sam is on, **Get involved**, and open-team Projects; no People or Oversight |

Things to try:

- As Maria, choose **Start a Project**, pick **Potluck or Picnic** (or describe anything in one sentence), and answer the Planner's three questions. Nothing is added until you choose **Add to Project**.
- Open **Fall Church Picnic**: a Sign-up sheet where each Slot is a food category and people say what they are bringing. Its Public link shows the dishes without names.
- As Sam, open **Get involved** on a phone-sized window and sign up for an open spot.
- As Daniel, open **Oversight** to see who is serving a lot and who has never been asked.

Non-demo Organizations use email magic links only; the Explore buttons appear when `organization.demo?` is true.

Admins and anyone who has led a Project can create Projects. Admins and Leaders of an active Project can view Oversight. Only Admins can change Oversight settings.

## How the AI Planner works

1. A Leader chooses the kind of Project, or describes something else in one sentence. Flockwork creates a quiet Project shell and opens its Planner.
2. Each turn, `Planner::ContextBuilder` is the only code that calls the model (via `Rails.configuration.x.planner_provider`). The model returns one question card with 3–5 options and an updated Project preview.
3. Answers enqueue `PlannerStepJob` (Solid Queue). Suggested Tasks, Schedule items, Slots, Budget lines, Lists, Tools and Skills stay visible as **Suggestions · not added yet**. A Leader can edit or remove each item from its ⋯ menu and undo a removal.
4. One final **Add to Project** action writes every visible Suggestion into real Project records atomically. Nothing reaches the Project before that action.

**Provider:** `Planner::Providers::Llm` uses RubyLLM with provider `PLANNER_LLM_PROVIDER` (default `openrouter`) and model `PLANNER_LLM_MODEL` (default `anthropic/claude-sonnet-5.5`). Set `OPENROUTER_API_KEY` in `.env.development.local` (see setup).

**Preview contract:** build-as-you-go responses include the model's current snapshot in `added`. Stable `source_key` values keep edits attached across answers, omitted items stay in the preview, and `removed_ids` is the only way the model can ask to remove prior work. A Leader's edits and removals remain authoritative.

Tests stub the provider with `Planner::Providers::Fake` and assert no Person name, email, or phone appears in the JSON sent to the provider.

## Stack

- **Rails 8.1** + Hotwire (Turbo, Stimulus), importmap, Propshaft
- **Ruby 4.0.9** (see `.ruby-version`; use [mise](https://mise.jdx.dev/) locally)
- **PostgreSQL**; **Solid Queue**, **Solid Cache**, **Solid Cable** (database-backed)
- **Action Text**, **Active Storage** (variants via `image_processing`)
- **Tailwind CSS v4** (`tailwindcss-rails`, tokens in `app/assets/tailwind/application.css`, spec in [DESIGN.md](DESIGN.md))
- **ruby_llm** 2.1.1 for the Planner ([config/initializers/ruby_llm.rb](config/initializers/ruby_llm.rb))
- **Fonts:** Mattone (display/wordmark, SIL OFL—[app/assets/fonts/Mattone-OFL.txt](app/assets/fonts/Mattone-OFL.txt)) and Mona Sans (UI), loaded via [app/assets/stylesheets/fonts.css](app/assets/stylesheets/fonts.css)

## Backups

Production runs an off-site backup at 4:30am daily. PostgreSQL custom-format dumps go to `db/` in the backup bucket. Active Storage files remain on the local Disk service and are copied to `storage/<key>` in the backup bucket. Database dumps older than 14 days are pruned, while the seven newest are always kept.

Set `BACKUP_BUCKET_NAME`, `BACKUP_BUCKET_ENDPOINT`, `BACKUP_BUCKET_REGION`, `BACKUP_BUCKET_ACCESS_KEY_ID`, and `BACKUP_BUCKET_SECRET_ACCESS_KEY`. Without all five, the backup is a no-op.

Restore a database dump with:

```bash
pg_restore --clean --if-exists --no-owner -d <url> <file>
```

Restore each `storage/<key>` object beneath the Disk root using Active Storage's two-level directory layout:

```bash
export AWS_ACCESS_KEY_ID="$BACKUP_BUCKET_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$BACKUP_BUCKET_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$BACKUP_BUCKET_REGION"
key=<key>
mkdir -p "/rails/storage/${key:0:2}/${key:2:2}"
aws --endpoint-url "$BACKUP_BUCKET_ENDPOINT" s3 cp "s3://$BACKUP_BUCKET_NAME/storage/$key" "/rails/storage/${key:0:2}/${key:2:2}/$key"
```

Disk stores each key at `<root>/<first two key characters>/<next two key characters>/<key>`.

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
| `SENDLY_SANDBOX_API_KEY` | Optional Sendly SMS sandbox client. |
| `POSTHOG_API_KEY` | Optional PostHog (US cloud) product analytics. Unset sends nothing; set it in production. |

For production SMS notifications, set `SENDLY_API_KEY` and run the Solid Queue
worker. People choose their notification channels in **My profile > Notifications**;
SMS stays off until they enable it.

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

## Work in an Amp orb

Amp runs `.agents/setup` to prepare its reusable project snapshot. Setup installs
the pinned Ruby and Bundler, gems, npm dependencies, Playwright Chromium, PostgreSQL,
Docker, libvips, and WebP tools. It prepares the development database with synthetic
demo data and builds Tailwind CSS. Repeated runs preserve the database and reuse
installed tools and caches. `.agents/resume` checks PostgreSQL without reinstalling
dependencies.

Run `amp orb services ensure` to start Docker, Rails with its Solid Queue worker,
and the Tailwind watcher. Open the printed Flockwork portal URL and choose an
**Explore** button. PostgreSQL runs as a system service; tests use a separate
Postgres 18 container through Testcontainers. The first test run downloads the
container image if Docker does not have it yet.

Run `bin/rails test` or `bin/rails test:system` after the services start. For landing
page recordings, use the cached Chromium instead of installing Google Chrome:

```bash
CHROME_PATH="$(node -p 'require("playwright").chromium.executablePath()')" bin/marketing-animations
```

The demo and tests need no API credentials. For live AI, Planning Center, or SMS,
configure the optional keys listed above in Amp secrets. Setup does not authenticate
external services or copy credentials into the snapshot.

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

## Data and privacy

- Grace Fellowship and all demo People are **synthetic**; no real congregant data ships in the repo.
- API keys and credentials stay in env vars or Rails credentials—never committed (see `.gitignore`).
- **Notes** use visibility enums; `Policy.visible_notes` filters what each role can load in SQL (Person notes are always Admins-only). The Planner context builder does not include Note bodies or Person records.
