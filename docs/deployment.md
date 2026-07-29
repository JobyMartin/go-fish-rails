# Deployment (Fly.io)

Deployed as a Docker image built from the repo's `Dockerfile` — Fly builds it, so **the
Dockerfile is the deploy config**. `fly.toml` is committed; point the launch form's "Config
path" at it (or leave it blank, since it's at the repo root) so Fly uses it instead of
generating its own.

## Required environment

The two `GOOD_JOB_*` vars live in `fly.toml`'s `[env]`. The other three are **credentials**
and must go through `fly secrets set` — `fly.toml` is committed, so anything in `[env]` is
public. Same for the launch form's env-var table: it writes to `fly.toml`.

| Variable | Where it's set | What breaks without it |
|---|---|---|
| `RAILS_MASTER_KEY` | `fly secrets set` ← `cat config/master.key` | Won't boot. The key is in both `.gitignore` and `.dockerignore`, so an env var is the *only* way it reaches the container |
| `DATABASE_URL` | `fly secrets set` ← Neon/Supabase | Won't boot |
| `REDIS_URL` | `fly secrets set` ← `fly redis status <name>` | Nothing, visibly — see "The silent ones" below |
| `GOOD_JOB_EXECUTION_MODE` | `fly.toml` `[env]`, `async` | Nothing, visibly — see below |
| `GOOD_JOB_ENABLE_CRON` | `fly.toml` `[env]`, `true` | `ArchiveGameJob` never runs |

`GAME_PLATFORM_DATABASE_PASSWORD` (referenced in `config/database.yml`) is **not needed**.
Rails merges `DATABASE_URL` on top of `database.yml`, overriding the hardcoded `username`
and `password` in the `production:` block.

## The silent ones

Two misconfigurations produce a **healthy-looking app that quietly doesn't work**. Both
are worth checking first when "live updates are broken in production."

**`REDIS_URL` missing.** `config/cable.yml` falls back to `redis://localhost:6379/1`, so
Action Cable initializes without complaint and then fails to broadcast to anyone.

**`GOOD_JOB_EXECUTION_MODE` unset.** GoodJob defaults to `:external` in production, meaning
jobs only run if a separate worker process exists. Fly runs one web machine and no worker.
`Game` uses `broadcast_refresh_later_to` and `broadcast_append_later_to` — the `_later_`
variants *enqueue jobs* — so every live update lands in the queue and stays there. `async`
runs the executor inside the web process, which is correct for a single machine.

## Provisioning

Create the Neon project in the browser first (pick a region near `dfw`) and copy its
connection string. Then:

```sh
fly redis create           # match the app's region (dfw)
fly redis status <name>    # prints the connection URL
fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)" \
                REDIS_URL="redis://default:...@fly-<name>.upstash.io:6379" \
                DATABASE_URL="postgresql://...@ep-xxx.neon.tech/neondb?sslmode=require"
```

Redis is Upstash-backed but provisioned inside the Fly org, so the connection stays private.
If the URL Fly returns uses the `rediss://` scheme (TLS), **keep it** — the `redis` gem
handles both, but rewriting the scheme breaks the connection. Same for Neon's
`?sslmode=require` — dropping it breaks the connection.

## Why Redis and not `async`

`config/cable.yml` production uses `adapter: redis`. Action Cable's `async` adapter would
work fine on a single Fly machine and needs no infrastructure at all — but **configuring a
real Redis server is part of the apprenticeship exercise** (instructor's call, 2026-07-29).
Don't "simplify" it away. Same reasoning as everything else in AGENTS.md: the deliberately
chosen pattern beats the technically-lighter alternative here.

The `redis` gem ships commented out in a fresh Rails app. It's uncommented in the `Gemfile`
for exactly this reason.

## Keeping it free

This is a learning deploy, so cost matters more than resilience. **Don't check "Managed
Postgres"** in the launch form — Fly MPG has no free tier and starts at $38/mo. Fly itself
has no free allowance either since 2024-10-07; new orgs are pay-as-you-go.

| Piece | Choice | Free tier |
|---|---|---|
| Postgres | Neon | permanent, no card, 0.5GB, 100 compute-hours/mo, scales to zero after 5 min idle |
| Redis | Upstash (via `fly redis create`) | 256MB, 500K commands/mo |
| App machine | Fly, `auto_stop_machines = "stop"` | not free, but you only pay for machine time |

**The trap this creates.** `GOOD_JOB_EXECUTION_MODE=async` makes GoodJob poll the database
every few seconds forever. On a free scale-to-zero database that means compute *never*
sleeps — 730 hours/month against a 100 compute-hour quota, so the database suspends itself
partway through the month and the app breaks with no deploy having happened.

`fly.toml` solves it with `auto_stop_machines = "stop"` and `min_machines_running = 0`:
machine sleeps when idle → GoodJob stops polling → the database sleeps too. The cost is a
few seconds of cold start on the first request after an idle period. **If you ever set
`min_machines_running = 1`, budget for an always-on database.**

Supabase is the lower-thought alternative — it doesn't meter compute-hours, it just pauses
the project after ~7 days idle, which you un-pause with a click.

## Launch form settings

`fly.toml` already sets the internal port (80), memory (512MB), and the `GOOD_JOB_*` vars,
so the form's equivalents are redundant — but the form may not read the file before the
first deploy. If you're filling it in by hand: **internal port `80`**, not the default
`8080` (`Dockerfile`'s `CMD` is `./bin/thrust`, and Thruster listens on 80; keeping 8080
means also setting `HTTP_PORT=8080`), and **512MB memory** — 256MB is not enough for
Rails 8 + Puma. Leave working directory and config path empty.

## Dockerfile notes

Two things about the generated `Dockerfile` needed correcting, both build-time failures:

**`ARG RUBY_VERSION` must track `.ruby-version`.** The generated value lagged behind. This
matters more than a normal version bump because `Gemfile.lock` is a **Bundler 4** lockfile —
it carries `sha256=` checksums that older bundlers can't parse, and `BUNDLE_DEPLOYMENT="1"`
means bundler can't fall back to re-resolving.

**The build stage needs Node and yarn.** The app uses `jsbundling-rails`, which hooks
`javascript:build` onto `assets:precompile`, so `assets:precompile` shells out to `yarn`.
The generated Dockerfile had no Node at all, and `app/assets/builds/*` is in `.dockerignore`,
so the compiled JS isn't copied in either — the build died at `yarn: not found`. The install
block plus `yarn install --frozen-lockfile` runs *before* `COPY . .` so the layer caches on
`package.json`/`yarn.lock` alone.

## Verifying a build locally

Faster than a failed deploy. The image boots without a database, so config can be inspected
directly:

```sh
docker build -t game_platform .
docker run --rm -e SECRET_KEY_BASE_DUMMY=1 -e REDIS_URL="redis://fake:6379/1" \
  -e GOOD_JOB_EXECUTION_MODE=async game_platform \
  ./bin/rails runner 'puts ActionCable::Server::Base.config.cable["adapter"];
                      puts GoodJob.configuration.execution_mode.inspect'
```

`SECRET_KEY_BASE_DUMMY=1` stands in for `RAILS_MASTER_KEY` — the same trick the Dockerfile
uses to precompile assets without the real secret.
