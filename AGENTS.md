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
- Ruby's implicit block parameter `it` is used throughout (e.g. `players.find { it.id == x }`).
- **Comments are a last resort, not a courtesy.** Before writing one, ask: can this be
  induced by reading the code? If yes, the comment is dead weight — delete it, or better,
  rename/restructure so the code says it. If no — the reason genuinely can't be derived from
  the code, tests, or a linked doc (a business rule, a bug workaround, "why this exists at
  all") — that's the only case a comment earns its place. When in doubt, put the explanation
  in the relevant `docs/*.md` file instead of the source; code comments rot in place, docs get
  read and updated.

## Gotchas

- **`William` is the discard pile, not an AI.** In Crazy Eights, `CrazyEights::William` is
  simply the collection of placed cards; `william.active_card` is the top of the discard
  pile. The name is an inside joke.
- **Game state is one jsonb blob.** History/replay lives entirely inside the serialized
  `game_state` column, not in normalized tables — adding a field means updating the
  domain object's `as_json`/`from_json`/`load`/`dump`.
- **Deal counts depend on player count** in all three games (see the game docs).
- `ArchiveGameJob` auto-archives any game untouched for 2+ days, on a GoodJob schedule.
- **Routes are inconsistent** — they grew through the apprenticeship's learning phases
  (e.g. `users/show` as a GET path, repeated `member` blocks). Don't treat existing route
  style as the intended convention.
- **`GamesController#play` checks `game_over?` *before* playing the turn**, so the turn that
  *ends* a game redirects to the game page, not the winner screen — the winner screen is only
  reached on a later request against an already-over game. (The `CrazyEights::Game#winner`
  `NoMethodError` this used to trip over is fixed as of Improvement 2.)
- **`GoFishGame#play_turn` truncates the rank** via `params[:rank].chars.first`, so a two-
  character ask (`'10'`) silently becomes `'1'` — an invalid rank. Latent bug; single-char
  ranks (`'A'`, `'K'`) are unaffected. (Untouched by Improvement 2 — deliberately out of scope.)
- **`CrazyEightsGame#play_turn` computes its own `active_card`** (always `william.active_card`)
  and reads `params[:rank]` as the placed card; a **blank `:rank`** triggers the
  `draw_until_playable` loop — drawing from the deck until a card matches the active card's
  suit or rank. Both subclasses now share one polymorphic `play_turn(params)` signature but
  read different keys (Go Fish: `:player`/`:rank`; Crazy Eights: `:rank`/`:suit`).
- **Game-over is computed but never persisted.** `Game#end` (sets `ended_at`) has no caller,
  and the `players.winner` boolean is never written — only the in-memory domain `winner` is
  computed, for the winner screen. So `Game#status` never returns `Finished` and
  `StatsController` win % is permanently `0%`. Surfaced by the rails-audit; deferred out of the
  current improvement round (see `docs/improvement-cards.md`).
- **Game actions are participant-gated; `join` is not.** `GamesController` runs `set_game` then
  `require_participation` (`before_action`, `only: %i[show start play winner]`) — a non-participant
  is redirected to the lobby with a flash instead of reading state or hitting the old `show`
  `NoMethodError` (`find_player` → `nil` → `current_player.hand`). `PlayersController#create` (join)
  is **deliberately left open** — joining is a non-participant action by nature. Card 3 of
  `docs/improvement-cards.md`, **complete** (see `docs/brave-card-3-authorize-game-actions.md`).

## Key context

- `docs/architecture.md` — model relationships, STI, and the serialization pattern
- `docs/testing.md` — TDD workflow and spec organization
- `docs/games/go-fish.md` — Go Fish rules and implementation notes
- `docs/games/crazy-eights.md` — Crazy Eights rules, William, and implementation notes
- `docs/improvement-plan.md` — foundation work for adding a third game: (1) lock the shared
  "game contract" with tests, then (2) replace type-branching with polymorphic dispatch + a
  game registry. **Both improvements are complete.** The optional stretch item (extract a
  shared `Card`/`Deck`) is now Card 2 of `docs/improvement-cards.md`, **complete**.
- `docs/improvement-1-breakdown.md` — Improvement 1 (tests-only), **complete**: STI subclass
  specs, serialization round-trips, the shared `"a persisted card game"` example, and the
  winner/game-over system specs.
- `docs/improvement-2-breakdown.md` — Improvement 2 (the refactor), **complete**: all five
  deliverables done — `CrazyEights::Game#winner`, the `Game::PLAYABLE_TYPES` registry,
  polymorphic `build_game`, the unified `play_turn(params)`, and removal of the last stray
  view conditional. No `type ==` branching remains in source.
- `docs/improvement-cards.md` — the post-Improvement-2 scoped round: three ~1–2h cards —
  (1) a `RoundResult` feed presenter **(done)**, (2) the shared `Card`/`Deck` extraction
  **(done)**, (3) authorization on game actions **(done)**.
  `RAILS_AUDIT_REPORT.md` (repo root) is the
  full audit behind them; its one remaining High finding (game-over persistence)
  maps to the gotcha above.
- `docs/brave-card-1-round-feed-presenter.md` — BRAVE breakdown for Card 1 (the feed presenter),
  **complete**. `RoundFeed` (+ `FeedLine`) at `app/models/round_feed.rb` is a namespace-neutral
  presentation seam: each `RoundResult#feed_lines` delegates to it, and both game partials
  iterate `result.feed_lines` (styling by `role`: `action`/`player_response`/`game_response`)
  instead of branching on `for_other_players.count`. The `count == 3` path was dead then and is
  **preserved** (still dead) — a pure, behavior-identical refactor. See `spec/models/round_feed_spec.rb`.
- `docs/brave-card-2-shared-card-deck.md` — BRAVE breakdown for Card 2 (shared `Card`/`Deck`),
  **complete**. `Card`/`Deck` now live at top level (`app/models/card.rb`, `app/models/deck.rb`);
  the per-game copies are deleted and bare `Card`/`Deck` refs inside `module GoFish` /
  `module CrazyEights` resolve to them via constant lookup. Went with Approach A (one
  whole-deck shuffle) — the full suite stayed green, confirming the Go Fish per-suit shuffle
  was an untested artifact, not pinned behavior. See `spec/models/card_spec.rb` and
  `spec/models/deck_spec.rb`.
- `docs/brave-card-3-authorize-game-actions.md` — BRAVE breakdown for Card 3 (authorize game
  actions), **complete**. Two scoped before_actions in `GamesController` — `set_game` (drops the
  repeated `Game.find`) then `require_participation` (`@game.users.include?(Current.session.user)`,
  else redirect to lobby with a flash), both `only: %i[show start play winner]`. Decisions held:
  **include `winner`** (leaks state like `show`); **leave `join` alone**; **redirect-with-flash,
  not 404**. Discovered during implementation: **the application layout rendered no flash at all**
  (only the auth pages did), so flash had to be wired into the layout. (Superseded: flash now
  renders through a shared `app/views/shared/_flash.html.slim` partial in **both** layouts — see
  `docs/games/rummy.md` "Surfacing invalid moves".) Non-participant
  coverage is system-spec only (`spec/system/games_spec.rb`) — the shared `before_action` guards
  all four actions, so the two GET cases pin the POST cases too.
- `docs/games/rummy.md` — **Rummy, the third game: wired in, with real turn logic.**
  Registered in `Game::PLAYABLE_TYPES`, real `Rummy::*` domain objects, draw/meld/lay-off/
  discard all implemented, click-to-select hand UI via a Stimulus controller, and a real
  per-player-count `deal!` (2p → 10, 3–4p → 7, 5–6p → 6). `mockup-html/rummy.html` remains
  the visual mockup reference. **Invalid moves raise `Rummy::InvalidMove`** (the app's one
  turn-validation exception), surfaced as an auto-dismissing flash toast — see "Surfacing
  invalid moves".
