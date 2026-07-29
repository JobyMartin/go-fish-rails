# Deployment (Fly.io)

**Live at https://academy-game-platform.fly.dev** (app `academy-game-platform`, region `dfw`).

Deployed as a Docker image built from the repo's `Dockerfile` — Fly builds it, so **the
Dockerfile is the deploy config**. `fly.toml` is committed and holds everything non-secret.

Deploy with `fly deploy`. Don't use `fly launch` — it regenerates `fly.toml`. To create the
app without deploying, `fly apps create <name>`, which explicitly leaves `fly.toml` alone.

## Required environment

The two `GOOD_JOB_*` vars live in `fly.toml`'s `[env]`. The other three are **credentials**
and must go through `fly secrets set` — `fly.toml` is committed, so anything in `[env]` is
public. Same for the launch form's env-var table: it writes to `fly.toml`.

| Variable | Where it's set | What breaks without it |
|---|---|---|
| `RAILS_MASTER_KEY` | `fly secrets set` ← `cat config/master.key` | Won't boot. The key is in both `.gitignore` and `.dockerignore`, so an env var is the *only* way it reaches the container |
| `DATABASE_URL` | **set for you** by `fly postgres attach` | Won't boot |
| `REDIS_URL` | `fly secrets set` ← printed by `fly redis create` | Nothing, visibly — see "The silent ones" below |
| `GOOD_JOB_EXECUTION_MODE` | `fly.toml` `[env]`, `async` | Nothing, visibly — see below |
| `GOOD_JOB_ENABLE_CRON` | `fly.toml` `[env]`, `true` | `ArchiveGameJob` never runs |
| `HTTP_PORT` | `fly.toml` `[env]`, `8080` | **Won't serve** — see "Port 8080, not 80" |

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
runs the executor inside the web process.

## Port 8080, not 80

Thruster defaults to port 80, but the `Dockerfile` runs as `USER 1000:1000` and **non-root
cannot bind privileged ports**. On port 80 Thruster dies immediately with:

```
{"level":"ERROR","msg":"Failed to start HTTP listener","error":"listen tcp :80: bind: permission denied"}
```

Fly's proxy then reports `instance refused connection. is your app listening on 0.0.0.0:80?`
and the machines crash-loop while still showing `started` in `fly status` — which reads like
a networking problem rather than a permissions one. This is why Fly's default is 8080.

`HTTP_PORT` and `http_service.internal_port` must match. Change one, change both.

## Provisioning

```sh
fly apps create academy-game-platform

# Unmanaged Fly Postgres: ~$2/mo, vs $38/mo minimum for `fly mpg` (Managed).
# Unsupported by Fly and you own backups/recovery — fine for a learning deploy.
fly postgres create --name academy-game-platform-db --region dfw \
  --initial-cluster-size 1 --vm-size shared-cpu-1x --volume-size 1 --autostart

# Creates a database + user and sets DATABASE_URL on the app for you.
fly postgres attach academy-game-platform-db --app academy-game-platform

# `--enable-prodpack=false` is required: without it the command prompts about a
# $200/mo add-on and fails outright when run non-interactively.
fly redis create --name academy-game-platform-redis --region dfw \
  --no-replicas --enable-eviction --enable-prodpack=false

fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)" \
                REDIS_URL='redis://default:...@fly-....upstash.io:6379'
fly deploy
```

`attach` sets `DATABASE_URL` with `?sslmode=disable`. That's correct — the connection uses
Fly's private WireGuard network over `.flycast`, which is already encrypted.

Single-quote the Redis URL. These passwords contain characters zsh would expand.

Upstash's own output warns that frequent pollers get expensive. **It doesn't apply here**:
Action Cable holds one long-lived blocking `SUBSCRIBE`. GoodJob polls the *database*, not Redis.

## Why Redis and not `async`

`config/cable.yml` production uses `adapter: redis`. Action Cable's `async` adapter needs no
infrastructure at all, and **configuring a real Redis server is part of the apprenticeship
exercise** (instructor's call, 2026-07-29) — reason enough on its own.

But it also turned out to be load-bearing, immediately: **Fly's first deploy creates two
machines** for high availability, even with `min_machines_running = 0`. `async` is in-process
pub/sub, so with two machines a broadcast would reach only whichever one served the request
— and fail silently for everyone connected to the other. Redis is what makes this deployment
correct, not just pedagogically tidy.

The `redis` gem ships commented out in a fresh Rails app. It's uncommented in the `Gemfile`
for exactly this reason.

## Cost

Fly has **no free allowance** since 2024-10-07; new orgs are pay-as-you-go. Roughly:

| Piece | Choice | Cost |
|---|---|---|
| Postgres | unmanaged `fly postgres` | ~$2/mo (shared-cpu-1x/256MB + 1GB volume), `--autostart` sleeps it |
| Redis | Upstash via `fly redis create` | free tier: 256MB, 500K commands/mo |
| App machines | Fly, `auto_stop_machines = "stop"` | pay only for running time; **two machines by default** |

`fly mpg` (Managed Postgres) is the option behind the launch form's "Managed Postgres"
checkbox. It starts at **$38/mo** with no free tier. Don't check it for a learning deploy.

`fly scale count 1` drops to a single machine and halves the machine cost — but then read
"Why Redis and not `async`" before assuming anything about cable adapters can be simplified.

**Auto-stop is why cold starts are slow.** Measured: **12.5s cold, 0.7s warm.** Both the app
machine and (with `--autostart`) the Postgres machine have to wake.

An earlier draft of this doc recommended Neon's free tier instead. That works, but
`GOOD_JOB_EXECUTION_MODE=async` polls the database every few seconds forever, which prevents
a scale-to-zero database from ever sleeping — 730 hours/month against Neon's 100
compute-hour free quota, so it suspends itself mid-month. Fly Postgres has no such metering,
which is why it's the simpler choice here.

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

## `release_command` is `db:migrate`, not `db:prepare`

On an **empty** database `db:prepare` loads the schema and then runs `db:seed`, and
`db/seeds.rb` opens with `include FactoryBot::Syntax::Methods`. FactoryBot is a dev/test gem,
absent from the production image, so the first deploy died with:

```
NameError: uninitialized constant FactoryBot
/rails/db/seeds.rb:11
Tasks: TOP => db:prepare
```

`db:migrate` never seeds, which is what production wants anyway.

`bin/docker-entrypoint` *also* runs `db:prepare` on every machine start, and that's fine —
once migrations have run, `db:prepare` sees an initialized database and skips both the schema
load and the seed. **It would bite again on a genuinely empty database**, so if this app is
ever redeployed against a fresh one, expect it from the entrypoint rather than the release
command.

Keeping the migration in `[deploy] release_command` is deliberate: a failed migration aborts
the deploy cleanly instead of crash-looping machines.

## Verifying production

A 200 on the homepage does not prove the database or Redis work — a missing `REDIS_URL`
fails silently. Check all of it at once:

```sh
fly ssh console -a academy-game-platform -C "bin/rails runner '
  puts ActiveRecord::Base.connection.tables.size;
  puts ActionCable.server.pubsub.class;
  require %q{redis}; puts Redis.new(url: ENV[%q{REDIS_URL}]).ping;
  puts GoodJob.configuration.execution_mode.inspect'"
```

Expected: a table count (11 at time of writing),
`ActionCable::SubscriptionAdapter::Redis`, `PONG`, `:async`. Anything else — particularly
`ActionCable::SubscriptionAdapter::Async` — means a secret didn't land.
