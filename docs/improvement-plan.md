# Card Game Platform — Foundation Improvement Plan

## Context

The platform is a teaching Rails app (Go Fish + Crazy Eights) that will grow to more
games. The goal is a solid foundation before adding a third game. The biggest concern is
**duplication between the two games**, and the chosen approach is **balanced**: remove the
seams that clearly hurt, but keep each game readable and stop short of deep inheritance /
metaprogramming (this is a teaching repo).

A codebase review pinpointed the root cause: the app **already has STI subclasses**
(`GoFishGame`/`CrazyEightsGame`) but three places bypass that polymorphism with hardcoded
`type == 'GoFishGame'` branches, and the shared infrastructure a new game relies on is
almost entirely untested. Fixing those two things is what makes a third game cheap and
safe to add.

Key evidence:
- `app/models/game.rb:51-57` — `build_game` is an `if/else`; the `else` silently makes
  **any** non-Go-Fish type a Crazy Eights game.
- `app/controllers/games_controller.rb:49-53` — `play` branches on `@game.type` and calls
  the two subclasses' **different `play_turn` signatures**; `play_crazy_eights` (a
  game-specific private method) lives in the shared controller.
- `app/views/crazy_eights_games/_crazy_eights_game.html.slim:60` — a stray
  `if game.type == "GoFishGame"` inside the Crazy Eights partial.
- `app/views/games/new.html.slim:4` — the playable-game list is a hardcoded array
  `['Go Fish', 'Crazy Eights']`; `create` reconstructs the class via
  `"#{type}Game".delete(' ').constantize` (fragile string surgery); `game_params` even
  permits a dead `:game_type`.
- `spec/models/go_fish_game_spec.rb` & `spec/models/crazy_eights_game_spec.rb` are empty
  `pending` stubs. The `serialize :game_state` DB round-trip is only asserted as "present
  after reload," never for fidelity. No `shared_examples`/`shared_context` exist for a new
  game to reuse. The Crazy Eights gameplay and the winner/game-over flows have no working
  end-to-end coverage (the winner spec is `pending: 'broken and cannot figure out'`).
- Latent bug: `GamesController#winner` calls `game_state.winner`, but only
  `GoFish::Game` defines `winner` — `CrazyEights::Game` does not.

Guiding principle for every change below: **make the existing STI polymorphism do the
work instead of adding new abstractions.** No new base-class hierarchy for the domain
objects in the two primary items.

> **Testing convention (repo-wide):** System specs (from the user's perspective) plus
> comprehensive model specs are the coverage mechanism. **Request specs are almost never
> used** — reach for one only in the rare case where a system spec would have to reach
> across too many layers. This plan follows that convention.

---

## Improvement 1 (do first): Lock the shared "game contract" with tests

**Why first:** these tests characterize current behavior so Improvement 2's refactor is
safe, and they independently close the biggest test gap — the shared infrastructure every
new game builds on. They also *document the interface* a new game must satisfy, which is
what actually makes extension safe.

**What to add**
1. **STI subclass specs** — replace the empty stubs in `spec/models/go_fish_game_spec.rb`
   and `spec/models/crazy_eights_game_spec.rb` with real coverage of each subclass's
   `play_turn` (the Go Fish fish-and-skip branch; the Crazy Eights draw-until-playable
   loop in `app/models/crazy_eights_game.rb:8-14`).
2. **DB serialization round-trip spec** — a spec that starts a persisted game, plays a
   turn, `reload`s, and asserts *fidelity* of `game_state` (hands, deck size,
   round_results, current player, and William for CE) — not just presence. This guards the
   `serialize :game_state, coder:` mechanism that is the platform's core teaching goal.
3. **System spec coverage for the currently-untested end-to-end flows** (the repo's
   primary coverage mechanism). Fill the real gaps in `spec/system/games_spec.rb`: Crazy
   Eights playing a turn end-to-end (only creation + show render exists today), and the
   winner / game-over flow for **both** games (today `pending: 'broken and cannot figure
   out'` with large commented-out blocks). Driving the winner screen through the UI
   naturally surfaces the `CrazyEights::Game#winner` bug and exercises the `create`/`play`
   type dispatch end-to-end.
4. **A shared example** `it_behaves_like "a persisted card game"` in
   `spec/support/shared_examples/` (new) asserting the informal domain interface both
   games already honor: `deal!`, `find_player`, `current_player`, `players`,
   `round_results`, `game_over?`, `winner`, and a clean serialize→reload round-trip. Wire
   both `GoFishGame` and `CrazyEightsGame` into it.

**How this eases extension:** a third game gets a ready-made test template
(`it_behaves_like "a persisted card game"`) and an explicit, enforced contract instead of
re-inventing round-trip / STI / play_turn assertions from scratch.

**Representative files:** `spec/models/go_fish_game_spec.rb`,
`spec/models/crazy_eights_game_spec.rb`, `spec/system/games_spec.rb` (extend the pending /
Crazy-Eights gaps), `spec/support/shared_examples/persisted_card_game.rb` (new); reuse
existing `spec/factories/games.rb` (polymorphic `initialize_with`) and its `:in_progress`
trait, plus the existing system helpers in `spec/support/helpers/`.

---

## Improvement 2: Replace type-branching with polymorphic dispatch + one game registry

**Why:** this directly answers the top concern (duplication / "adding a game is
expensive"). Every hardcoded `type == 'GoFishGame'` branch is STI polymorphism done by
hand. Pushing each branch down onto the subclass — and sourcing the playable-game list
from one registry — means a third game adds a subclass + partial and touches **zero**
shared conditionals.

**What to change**
1. **Unify the `play_turn` interface.** Give each `<Name>Game` subclass a single
   `play_turn(params)` (or `play(params)`) that reads its own param shape, so
   `GamesController#play` becomes one polymorphic call:
   `@game.play_turn(params[:play_turn])`. Move `play_crazy_eights`'s logic
   (`games_controller.rb:66-72`) into `CrazyEightsGame`. Removes the controller `if/else`
   and the game-specific private method from the shared controller.
2. **Push `build_game` onto the subclass.** Replace `Game#build_game`'s `if/else`
   (`game.rb:51-57`) with each subclass knowing which domain `Game`/`Player` to build
   (e.g. a `build_game` override, or a `domain_game_class`/`domain_player_class` pair the
   base `start` uses). Deletes the silent `else`-is-CrazyEights trap.
3. **Introduce one game registry** as the single source of truth for playable types, e.g.
   `Game.playable_types` returning subclass metadata (class + human label). Drive
   `app/views/games/new.html.slim:4` from it and simplify `GamesController#create` to look
   up the class from the registry instead of `"#{type}Game".delete(' ').constantize`.
   Fix `game_params` (drop dead `:game_type`).
4. **Remove the stray view conditional** at
   `app/views/crazy_eights_games/_crazy_eights_game.html.slim:60`.
5. **Fix the `winner` inconsistency** so every subclass answers `winner`/`game_over?`
   (add `winner` to `CrazyEights::Game`, or define the contract on the AR base).

**Tests:** the Improvement 1 system specs, subclass specs, and shared example already pin
the behavior. Add model-level assertions that (a) an unknown/third type is *not* silently
coerced to Crazy Eights and (b) `Game.playable_types` lists exactly the playable
subclasses; add a system spec that the new-game form renders every registry entry.

**How this eases extension:** adding a third game becomes: create `app/models/<name>_game.rb`
(serialize coder + `play_turn` + `build_game`), the `app/models/<name>/` domain namespace,
one view partial, and register it. No edits to shared `if/else` branches.

**Representative files:** `app/models/game.rb`, `app/models/go_fish_game.rb`,
`app/models/crazy_eights_game.rb`, `app/controllers/games_controller.rb`,
`app/views/games/new.html.slim`,
`app/views/crazy_eights_games/_crazy_eights_game.html.slim`.

---

## Optional stretch (only if time remains): extract shared `Card` / `Deck`

`go_fish/card.rb` vs `crazy_eights/card.rb` are ~100% identical (CE only adds
`self.objectify`); the two `Deck`s differ only in *where* shuffling happens. A single
shared `Card`/`Deck` (a small shared module or plain shared class the namespaces reuse)
would remove the largest verbatim domain duplication. **Kept optional** because it edges
toward the "deep abstraction" the balanced principle says to avoid — do it only if the
shared version stays obvious and each game's card behavior remains readable. Skip the
serialization-concern extraction for now (it hides the very mechanism the repo teaches).

---

## Verification

- `bundle exec rspec` green locally (CI does **not** run specs).
- Specifically: `bundle exec rspec spec/models/go_fish_game_spec.rb
  spec/models/crazy_eights_game_spec.rb spec/system/games_spec.rb` and the shared example
  across both games.
- `bin/rubocop` clean.
- Manual smoke via `bin/dev`: create each game from the lobby, start, play a turn, reach
  the winner screen for **both** games (confirms the `winner` fix and polymorphic `play`).
- Regression guard: temporarily add a throwaway third STI subclass in a spec and confirm
  it is *not* coerced into Crazy Eights by `build_game`.

## Scope discipline

Two primary items, done well and independently pickup-able, in the order above
(tests → refactor). The stretch item is explicitly optional.
