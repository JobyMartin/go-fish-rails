# Deployment (Fly.io)

Deployed as a Docker image built from the repo's `Dockerfile` — Fly builds it, so **the
Dockerfile is the deploy config**. There is no `fly.toml` in the repo yet; the launch form
writes one.

## Required environment

Three of these are secrets. Set them with `fly secrets set`, **not** the env-var table in
the launch form — that table's values are written to `fly.toml` in plaintext, and two of
these are credentials.

| Variable | Source | What breaks without it |
|---|---|---|
| `RAILS_MASTER_KEY` | `cat config/master.key` | Won't boot. The key is in both `.gitignore` and `.dockerignore`, so an env var is the *only* way it reaches the container |
| `REDIS_URL` | `fly redis status <name>` | Nothing, visibly — see "The silent ones" below |
| `DATABASE_URL` | Fly, automatically | Won't boot. Check **Managed Postgres** at launch |
| `GOOD_JOB_EXECUTION_MODE` | set to `async` | Nothing, visibly — see below |
| `GOOD_JOB_ENABLE_CRON` | set to `true` | `ArchiveGameJob` never runs |

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

```sh
fly redis create           # match the app's region (dfw)
fly redis status <name>    # prints the connection URL
fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)" \
                REDIS_URL="redis://default:...@fly-<name>.upstash.io:6379"
```

Redis is Upstash-backed but provisioned inside the Fly org, so the connection stays private.
If the URL Fly returns uses the `rediss://` scheme (TLS), **keep it** — the `redis` gem
handles both, but rewriting the scheme breaks the connection.

## Why Redis and not `async`

`config/cable.yml` production uses `adapter: redis`. Action Cable's `async` adapter would
work fine on a single Fly machine and needs no infrastructure at all — but **configuring a
real Redis server is part of the apprenticeship exercise** (instructor's call, 2026-07-29).
Don't "simplify" it away. Same reasoning as everything else in AGENTS.md: the deliberately
chosen pattern beats the technically-lighter alternative here.

The `redis` gem ships commented out in a fresh Rails app. It's uncommented in the `Gemfile`
for exactly this reason.

## Launch form settings

- **Internal port: `80`**, not the default `8080`. `Dockerfile`'s `CMD` is `./bin/thrust`,
  and Thruster listens on 80. (Keeping 8080 means also setting `HTTP_PORT=8080`.)
- **Memory: 512MB minimum.** 256MB is not enough for Rails 8 + Puma.
- Leave working directory and config path empty.

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
