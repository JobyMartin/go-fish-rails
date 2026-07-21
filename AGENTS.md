# AGENTS.md

## What this is

A learning exercise (part of the Craftsmanship Academy apprenticeship) that teaches the
basics of **Rails, relational databases, Active Record, Hotwire, and PWAs** by building a
web platform for playing online card games — currently **Go Fish** and **Crazy Eights**.
Users sign up, create or join a game in a lobby, and play in real time. Because it's a
teaching vehicle, the patterns below are chosen deliberately to demonstrate concepts;
prefer following them over "better" alternatives.

## Tech stack

- **Ruby** (see `.ruby-version`) / **Rails 8.1**
- **PostgreSQL** via Active Record
- **Hotwire**: Turbo (including Turbo Streams broadcasting) + Stimulus
- **Views**: Slim, `simple_form` (custom inputs in `app/inputs/`), RoleModel **Optics** component styles
- **Assets**: esbuild (`yarn build`), PostCSS/SCSS
- **Background jobs**: GoodJob
- **Auth**: hand-rolled sessions (`has_secure_password` + `Current.session`)
- **PWA**: manifest + service worker with an offline fallback page
- **Testing**: RSpec, Capybara + Playwright driver, FactoryBot

## Running the app

```sh
bin/setup    # install deps, prepare DB, boot the dev server
bin/dev      # foreman: rails server + `yarn build --watch` + good_job worker
```

## Testing

```sh
bundle exec rspec                       # full suite
bundle exec rspec spec/models/go_fish   # a directory
bundle exec rspec path/to/spec.rb:42    # a single example by line
```

- **TDD is required.** Work outside-in: start with a system spec from the user's
  perspective, then write unit/model specs for each method/model you introduce to make it
  pass. Aim for a few green system specs backed by comprehensive model specs.
- System specs run under `rack_test` by default. Tag `:js` (Playwright) or `:chrome` only
  when a spec genuinely needs a real browser — a spec that relies on JS but isn't tagged
  will fail.
- **Prefer system specs for behavior coverage; request specs are almost never used.**
  System specs (from the user's perspective) plus comprehensive model specs do the
  coverage. Reach for a request spec only in the rare case where a system spec would have
  to reach across too many layers to exercise the behavior.
- **CI does not run the specs.** `.github/workflows/ci.yml` runs only RuboCop and security
  scans, so green CI does not mean the tests pass — run RSpec locally.

See `docs/testing.md` for the full workflow and spec layout.

## Linting & CI

```sh
bin/rubocop  # rubocop-rails-omakase house style
bin/ci       # run the full CI pipeline locally (setup + rubocop + security scans)
```

## Git / commits

- **Do not add a `Co-Authored-By: Claude` trailer** (or any AI co-author/attribution
  line) to commit messages or PR bodies. Keep the message to the change itself.

## Architecture (big picture)

Persisted games use **single-table inheritance**: a `Game` base model with `GoFishGame`
and `CrazyEightsGame` subclasses. All actual game logic lives in **plain Ruby objects**
under `app/models/go_fish/` and `app/models/crazy_eights/`, and each AR subclass
**serializes** its plain-Ruby game object into the `game_state` jsonb column via a custom
coder (`serialize :game_state, coder: GoFish::Game`). Teaching serialization is a core
goal, so **new games must follow this same split.**

The AR `Player` is just the join table between `User` and `Game`. The domain
`GoFish::Player` / `CrazyEights::Player` are plain objects that hold per-game
responsibilities and never touch the database (they're keyed by `user.id`).

See `docs/architecture.md` for the full model map and serialization details.

## Conventions (that RuboCop won't catch)

- **≤ 7 lines** per method and per RSpec `it` block.
- **No instance variables (`@`) except** in model `initialize` methods and controller
  endpoints. Everywhere else, use `attr_reader`/`attr_accessor` and `self.`.
- **One instance variable per controller action** (Rails convention).
- **Fat models, skinny controllers.** Push logic into the domain objects. (Existing code
  doesn't always live up to this — new code should.)
- **Reuse before building.** Reach for an existing Optics component or custom
  `simple_form` input before hand-writing markup or a new component.
- **BEM** for CSS class naming; component styles live in `app/assets/stylesheets/components/`.
- Ruby's implicit block parameter `it` is used throughout (e.g. `players.find { it.id == x }`).

## Gotchas

- **`William` is the discard pile, not an AI.** In Crazy Eights, `CrazyEights::William` is
  simply the collection of placed cards; `william.active_card` is the top of the discard
  pile. The name is an inside joke.
- **Game state is one jsonb blob.** History/replay lives entirely inside the serialized
  `game_state` column, not in normalized tables — adding a field means updating the
  domain object's `as_json`/`from_json`/`load`/`dump`.
- **Deal counts depend on player count** in both games (see the game docs).
- `ArchiveGameJob` auto-archives any game untouched for 2+ days, on a GoodJob schedule.
- **Routes are inconsistent** — they grew through the apprenticeship's learning phases
  (e.g. `users/show` as a GET path, repeated `member` blocks). Don't treat existing route
  style as the intended convention.
- **`winner` is Go Fish-only (latent bug).** `GamesController#winner` calls
  `game_state.winner`, but only `GoFish::Game` defines `winner` — `CrazyEights::Game` does
  not, so the CE winner screen raises `NoMethodError`. Tracked for fix in the improvement
  plan (Improvement 2). Related trap: `GamesController#play` checks `game_over?` *before*
  playing, so the turn that ends a game redirects to the game page, not the winner screen —
  the winner screen is only reached on a later request against an already-over game.
- **Type-branching bypasses the STI polymorphism** in three places (`Game#build_game`'s
  `if/else`, `GamesController#play`, and a stray conditional in the Crazy Eights partial),
  and `GamesController#create` rebuilds the class via string surgery
  (`"#{type}Game".delete(' ').constantize`). These are the target of Improvement 2.
- **`GoFishGame#play_turn` truncates the rank** via `inquired_rank.chars.first`, so a two-
  character ask (`'10'`) silently becomes `'1'` — an invalid rank. Latent bug; single-char
  ranks (`'A'`, `'K'`) are unaffected.
- **The two `play_turn` signatures differ, and the CE domain ignores one arg.**
  `GoFishGame#play_turn(inquired_player_id, inquired_rank)` vs.
  `CrazyEightsGame#play_turn(active_card, placed_card = nil)`. In Crazy Eights, `active_card`
  is a `Card`, `placed_card` is a `"rank suit"` string (`Card.objectify`'d); the *domain*
  `CrazyEights::Game#play_turn` ignores `active_card` entirely — it only matters to the AR
  wrapper's no-`placed_card` branch, which draws from the deck until a card matches the
  active card's suit or rank. Improvement 2 unifies these into one polymorphic signature.

## Key context

- `docs/architecture.md` — model relationships, STI, and the serialization pattern
- `docs/testing.md` — TDD workflow and spec organization
- `docs/games/go-fish.md` — Go Fish rules and implementation notes
- `docs/games/crazy-eights.md` — Crazy Eights rules, William, and implementation notes
- `docs/improvement-plan.md` — foundation work before a third game is added: (1) lock the
  shared "game contract" with tests, then (2) replace type-branching with polymorphic
  dispatch + a game registry. Read this before touching game dispatch or serialization.
- `docs/improvement-1-breakdown.md` — step-by-step Given/When/Then for Improvement 1
  (tests-only). **Improvement 1 is complete**: STI subclass `play_turn` specs, serialization
  round-trips, the shared `"a persisted card game"` example, and the winner/game-over system
  specs are all green. Two specs are deliberately `pending` on the undefined
  `CrazyEights::Game#winner` (shared example + system spec) — they auto-flag **FIXED** when
  Improvement 2 defines that method, which is the intended handoff signal.
