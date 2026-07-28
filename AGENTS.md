# AGENTS.md

## What this is

A learning exercise (part of the Craftsmanship Academy apprenticeship) that teaches the
basics of **Rails, relational databases, Active Record, Hotwire, and PWAs** by building a
web platform for playing online card games — currently **Go Fish**, **Crazy Eights**, and
**Rummy**.
Users sign up, create or join a game in a lobby, and play in real time. Because it's a
teaching vehicle, the patterns below are chosen deliberately to demonstrate concepts;
prefer following them over "better" alternatives.

## Tech stack

- **Ruby** (see `.ruby-version`) / **Rails 8.1**
- **PostgreSQL** via Active Record
- **Hotwire**: Turbo (including Turbo Streams broadcasting) + Stimulus
- **Views**: Slim, `simple_form` (custom inputs in `app/inputs/`), RoleModel **Optics** component styles
- **Assets**: Propshaft auto-links every file under `app/assets/stylesheets` (no manifest);
  esbuild (`yarn build`) bundles JS only — see `docs/architecture.md` "CSS / asset pipeline"
- **Background jobs**: GoodJob
- **Auth**: hand-rolled sessions (`has_secure_password` + `Current.session`)
- **PWA**: manifest + service worker with an offline fallback page
- **Testing**: RSpec, Capybara + Playwright driver, FactoryBot

## Running the app

```sh
bin/setup    # install deps, prepare DB, boot the dev server
bin/dev      # foreman: rails server + `yarn build --watch` + good_job worker
BULLET=1 bin/dev   # ...with Bullet's N+1 warnings; off by default, and very slow on perf-seeded data
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
- **Commit messages are header-only — no body.** One line, no blank line + explanatory
  paragraph underneath.

## Architecture (big picture)

Persisted games use **single-table inheritance**: a `Game` base model with `GoFishGame`,
`CrazyEightsGame`, and `RummyGame` subclasses. All actual game logic lives in **plain Ruby
objects** under `app/models/go_fish/`, `app/models/crazy_eights/`, and `app/models/rummy/`,
and each AR subclass **serializes** its plain-Ruby game object into the `game_state` jsonb
column via a custom coder (`serialize :game_state, coder: GoFish::Game`). Teaching
serialization is a core goal, so **new games must follow this same split.**

The AR `Player` is just the join table between `User` and `Game`. The domain
`GoFish::Player` / `CrazyEights::Player` are plain objects that hold per-game
responsibilities and never touch the database (they're keyed by `user.id`).

**Adding a game is polymorphic, not conditional** (as of Improvement 2). Each STI subclass
answers `build_game`, `play_turn(params)`, and `winner`; `Game::PLAYABLE_TYPES` is the single
registry the lobby form and `GamesController#create` read from. A third game = a new
`<name>_game.rb` (coder + those three methods), the `app/models/<name>/` domain namespace,
a view partial, and one registry entry — **no shared `if/else` to touch.**

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
- **Optics' root font size is 10px**, so an `18rem` panel renders 180px and `--op-space-scale-unit: 2rem` is 20px. Measure widths; don't eyeball.
- **Motion is finite and gated.** The app has exactly one animation (the Rummy post-draw card
  pulse): finite iteration count, wrapped in `prefers-reduced-motion: no-preference`, with a
  non-motion cue carrying the same message. Hold new motion to that bar, and prefer a local
  `@keyframes` over an animation library — `animate.css` was weighed and rejected (it doesn't
  fit Propshaft's no-tree-shaking auto-linking, and its classes fight BEM).
- **`.count` always issues SQL; `.size` reads a loaded association.** One such word cost the
  leaderboard 1,004 queries. Bullet flags it *Need Counter Cache*, not *USE eager loading*.
  `.empty?` is the same trap: on an unloaded relation it fires its own `SELECT`. `.load` first.
- Ruby's implicit block parameter `it` is used throughout (e.g. `players.find { it.id == x }`).
- **Comments are a last resort, not a courtesy.** Before writing one, ask: can this be
  induced by reading the code? If yes, the comment is dead weight — delete it, or better,
  rename/restructure so the code says it. If no — the reason genuinely can't be derived from
  the code, tests, or a linked doc (a business rule, a bug workaround, "why this exists at
  all") — that's the only case a comment earns its place. When in doubt, put the explanation
  in the relevant `docs/*.md` file instead of the source; code comments rot in place, docs get
  read and updated.

## Gotchas

- **`William` is the discard pile, not an AI.** In Crazy Eights, `CrazyEights::William` is simply
  the collection of placed cards; `william.active_card` is the top of the pile. Inside joke.
- **Game state is one jsonb blob.** History/replay lives inside the serialized `game_state`
  column, not normalized tables — a new field means updating `as_json`/`from_json`/`load`/`dump`.
- **Deal counts depend on player count** in all three games (see the game docs).
- `ArchiveGameJob` auto-archives any game untouched for 2+ days (GoodJob schedule) — but the
  lobby never filters on `archived_at`, so `/games` shows every game ever. See `docs/leaderboard.md`.
- **Routes are inconsistent** (e.g. `users/show` as a GET path, repeated `member` blocks) — they grew through the apprenticeship's phases; not the convention.
- **`GamesController#play` checks `game_over?` *before* playing the turn**, so the turn that
  *ends* a game redirects to the game page, not the winner screen — the winner screen is only
  reached on a later request against an already-over game. It re-checks *after* the turn to call
  `finish!`, so the win is recorded on the ending turn even though the redirect lags a request.
- **`GoFishGame#play_turn` truncates the rank** via `params[:rank].chars.first`, so a `'10'`
  ask silently becomes `'1'` — invalid. Latent bug, still open; single-char ranks are fine.
- **`CrazyEightsGame#play_turn` computes its own `active_card`** (always `william.active_card`)
  and reads `params[:rank]` as the placed card; a **blank `:rank`** triggers `draw_until_playable`,
  drawing until a card matches the active card's suit or rank. Both subclasses share one
  `play_turn(params)` signature but read different keys (Go Fish `:player`/`:rank`; CE `:rank`/`:suit`).
- **Game-over is persisted.** `Game#finish!` sets `ended_at` and writes `players.winner`, from
  `GamesController#play` once `game_state.game_over?`. Only games finished *after* this landed
  count — older rows have a `nil` `ended_at`. See `docs/leaderboard.md`.
- **`Player`'s `not_started` validation is `on: :create` deliberately.** Unscoped it runs on every
  save, so `player.update!(winner: true)` failed with "This game has started" — it made recording
  a winner impossible. Don't tidy the scope away.
- **`uniqueness: { case_insensitive: true }` is not a Rails option** and is silently ignored.
  `User#email_address` still carries it, so that check is case-*sensitive* (harmless only because
  `normalizes` downcases first). `username` uses the real key, `case_sensitive: false`.
- **Whose turn it is, and turn *order*, are enforced only in the view.** `drawn_this_turn` is
  serialized but never validated — it only sets `disabled:` on buttons — and no controller
  checks that the submitter is `current_player`. A crafted POST can discard before drawing, or
  act on **another player's hand**. Both open cards in `docs/improvement-cards.md`.
- **Game actions are participant-gated; `join` is deliberately not.** `require_participation`
  (`before_action, only: %i[show start play winner]`) redirects non-participants to the lobby;
  joining is a non-participant action by nature. `docs/brave-card-3-authorize-game-actions.md`.

## Key context

- `docs/architecture.md` — model relationships, STI, and the serialization pattern
- `docs/testing.md` — TDD workflow and spec organization
- `docs/games/go-fish.md` — Go Fish rules and implementation notes
- `docs/games/crazy-eights.md` — Crazy Eights rules, William, and implementation notes
- `docs/improvement-plan.md` + `improvement-1-breakdown.md` + `improvement-2-breakdown.md` —
  third-game foundations, **all complete**: the shared "game contract" (incl. the
  `"a persisted card game"` shared example), then polymorphic dispatch + `Game::PLAYABLE_TYPES`.
  **No `type ==` remains.**
- `docs/improvement-cards.md` — post-Improvement-2 round, **all three done** (feed presenter,
  shared `Card`/`Deck`, game-action authorization). `RAILS_AUDIT_REPORT.md` is the audit behind
  them; its last High finding (game-over persistence) is **closed**.
- `docs/leaderboard.md` — the `/leaderboard` page, winner persistence, and the **performance
  week**: 3,014 queries / 4,115 ms → 2 / 35 ms via a **Scenic database view**
  (`db/views/leaderboard_entries_v01.sql` + read-only `LeaderboardEntry`), sorted **and filtered** by
  Ransack, paginated by Kaminari — all three still net **3 queries / 25 ms**. Country filtering goes
  through a `belongs_to :user`, which is why **`User` has a `ransackable_attributes` returning
  `%w[country]` and nothing else**. Aggregation lives in the view, display rules in Ruby. **Never edit
  `_v01.sql` in place** — `rails g scenic:view leaderboard_entries` versions it. Indexes were
  *measured and rejected*. Also holds `perf:seed` / `perf:measure`, Bullet's cost model, the
  **`RANK()` rank column**, the filter panel, and `/games`.
- `docs/brave-card-1-round-feed-presenter.md` — **complete**. `RoundFeed` (+ `FeedLine`) at
  `app/models/round_feed.rb` is a namespace-neutral seam; every game partial iterates
  `result.feed_lines`. **Roles are positional** — first `action`, last `game_response`, middles between.
- `docs/brave-card-2-shared-card-deck.md` — Card 2 (shared `Card`/`Deck`), **complete**. Both live
  at top level; bare refs inside `module GoFish` / `module CrazyEights` resolve via constant lookup.
- `docs/brave-card-3-authorize-game-actions.md` — Card 3 (authorize game actions), **complete**;
  the gotcha above is the short version. The doc holds the decisions (include `winner`, leave
  `join` open, redirect-with-flash over 404) and why coverage is system-spec-on-the-GETs only.
- `docs/games/rummy.md` — **Rummy, the third game: wired in, with real turn logic.** Registered
  in `Game::PLAYABLE_TYPES`, real `Rummy::*` domain objects, draw/meld/lay-off/discard all
  implemented, click-to-select hand UI via a Stimulus controller, per-player-count `deal!`.
  **Invalid moves raise `Rummy::InvalidMove`** — the app's one turn-validation exception,
  surfaced as a flash toast. **The stock refills from the discard pile, turned over and
  deliberately *unshuffled*** (Bicycle). The doc covers all of it; `mockup-html/rummy.html`
  is the visual reference.
- `docs/brave-rummy-feed-completeness.md` — **complete**. `Rummy::RoundResult` carries a `move`
  discriminator; one private `Game#record_move` sets `going_out` for **every** logged action.
  **`record_move` must precede `end_turn` in `#discard`** — `switch_turns` reassigns `current_player`.
- **Known spec flakes — a red suite here is often not your change.** Two are unpinned random decks:
  staging a hand leaves duplicates in the stock (~8%; stage through `start_rummy_game_with_state`),
  and Go Fish `spec/models/game_spec.rb:124` depends on the opponent holding exactly one Ace (~7%).
  Crazy Eights `games_spec.rb:157` joins them — rare, seen once in ~6 full runs, green 5/5 alone and
  3/3 for its file, and it is **not** `:js`, so it is the deck and not a browser race.
  Two `:js` intermittents are undiagnosed (`games_spec.rb:309`, `offlines_spec.rb:33`).
- **N+1s fail the suite.** `test.rb` runs `Bullet.raise` with no safelist, so an N+1 a spec
  exercises raises rather than passing quietly — Bullet is off in dev, so specs are the guard.
  Both notes: `docs/testing.md`.
