
# Improvement 2 — Step-by-Step: "Replace type-branching with polymorphic dispatch + one game registry"

> Source: `docs/improvement-plan.md` → *Improvement 2*.
> This is a **refactor**. Improvement 1 already pinned the behavior with model specs, a
> shared example (`"a persisted card game"`), and winner/game-over system specs — those are
> your safety net. Keep `bundle exec rspec` green at every step.

## Progress

**Improvement 2 complete.** All five deliverables shipped (A → E), each on its own commit:
A `CrazyEights::Game#winner`; B the `Game::PLAYABLE_TYPES` registry; C polymorphic
`build_game` (silent else-trap deleted + regression guard); D unified `play_turn(params)`
(controller is one polymorphic call, `play_crazy_eights` gone); E removed the last stray
`game.type` view conditional. Full suite green (205 examples, 0 failures); no `type ==`
branching remains in source. Deferred: the `params[:rank].chars.first` truncation bug (left
as-is) and the optional stretch item (shared `Card`/`Deck`).

## Guiding rule for this improvement

**Make the existing STI polymorphism do the work instead of adding new abstractions.**
Every hardcoded `type == 'GoFishGame'` branch is polymorphism done by hand — push each one
down onto the `GoFishGame` / `CrazyEightsGame` subclass. No new domain base-class hierarchy,
no metaprogramming (teaching repo — keep each game readable).

Conventions to honor (from `AGENTS.md`): ≤ 7 lines per method and per `it` block; no `@`
ivars outside model `initialize` / controller actions; one ivar per controller action;
Ruby's implicit block param `it`; fat models / skinny controllers. Reuse existing Optics
components / `simple_form` inputs before hand-writing markup.

The handoff signal from Improvement 1: two specs are `pending` on the undefined
`CrazyEights::Game#winner` (the shared example's "reports a winner" and the C3 system spec).
Deliverable A below defines that method, at which point RSpec reports those as **FIXED** and
fails the run until you delete the `pending` lines.

---

## The five type-branches this improvement removes

| # | Location | Smell |
|---|----------|-------|
| 1 | `app/controllers/games_controller.rb:49-53` | `if @game.type == 'GoFishGame'` + `play_crazy_eights` private method in the shared controller; two different `play_turn` signatures |
| 2 | `app/models/game.rb:51-57` | `build_game` `if/else` — the `else` silently makes **any** non-Go-Fish type a Crazy Eights game |
| 3 | `app/views/games/new.html.slim:4` + `games_controller.rb:15` | hardcoded `['Go Fish', 'Crazy Eights']`; `create` rebuilds the class via `"#{type}Game".delete(' ').constantize`; `game_params` permits a dead `:game_type` |
| 4 | `app/views/crazy_eights_games/_crazy_eights_game.html.slim:60` | stray `if game.type == "GoFishGame"` — **dead code** (see note) |
| 5 | `app/controllers/games_controller.rb:59-62` + `winner.html.slim` | `game_state.winner` raises `NoMethodError` for Crazy Eights (`CrazyEights::Game#winner` undefined) |

**Verified fact about #4:** `app/views/games/show.html.slim` renders `= render @game`, which
resolves polymorphically to `_go_fish_game` for `GoFishGame` and `_crazy_eights_game` for
`CrazyEightsGame`. So the `if game.type == "GoFishGame"` inside the **Crazy Eights** partial
never fires — the guarded `:player` select is dead code. Go Fish renders its own `:player`
select in `_go_fish_game.html.slim:77`. Deliverable E just deletes the dead line.

---

## Order of work

Ordered so the suite stays green and each step de-risks the next:

1. **A. Fix `winner`** — smallest, isolated, closes the known bug and flips the two
   Improvement 1 `pending` markers to green. Good warm-up.
2. **B. Game registry** (`Game.playable_types`) — the single source of truth the next two
   steps lean on.
3. **C. Polymorphic `build_game`** — push onto the subclasses; delete the silent `else`.
4. **D. Unify `play_turn`** — the biggest change; controller becomes one polymorphic call.
   Requires rewriting Improvement 1's Deliverable A specs to the new signature.
5. **E. Remove the stray view conditional** — trivial dead-code deletion; do last.

---

## Getting started (do this first)

```sh
bundle exec rspec   # confirm the Improvement 1 baseline is green (4 pending)
```

Note the two `pending` examples tied to `CrazyEights::Game#winner` — you'll watch them flip
to FIXED after Deliverable A. Reference facts (verified in the codebase):

- `Game#start` (`game.rb:22-27`) sets `started_at`, `self.game_state = build_game`, then
  `game_state.deal!`, then `save!`.
- `CrazyEights::Game#game_over?` ⇒ `players.any? { it.hand.empty? }`; the winner is the
  player who emptied their hand. `CrazyEights::Player` responds to `name` (default
  `'Crazy Eighter'`) and `id`.
- `GoFish::Game#winner` returns a **player object**; `winner.html.slim` renders
  `@winner.name`. So CE's `winner` must also return a player.
- The CE draw-until-playable `active_card` the controller passes in is *always*
  `@game.game_state.william.active_card` — the domain already has it, so the AR wrapper can
  read it internally instead of taking it as a param.
- Factory: `create(:game, type: 'CrazyEightsGame')`; add players with
  `create(:player, user:, game:)`.

---

## Deliverable A — Fix the `winner` inconsistency (plan item 5)

**Files:** `app/models/crazy_eights/game.rb`; then delete `pending` lines in
`spec/support/shared_examples/persisted_card_game.rb` and `spec/system/games_spec.rb` (C3).

**Goal:** every subclass answers `winner`, so `GamesController#winner` is truly polymorphic.

**Steps**
1. Run the two pending specs and confirm they still `pending` (baseline).
2. Add `CrazyEights::Game#winner` — return the player who emptied their hand:
   ```ruby
   def winner
     players.find { it.hand.empty? }
   end
   ```
   Keep it ≤ 7 lines. (Sanity-check tie/empty-deck edge cases against `game_over?`.)
3. Delete the `pending 'CrazyEights::Game#winner is undefined…'` guard line in the shared
   example and the `pending:` marker on the C3 system spec.

**A1 — `CrazyEights::Game#winner` returns the emptied-hand player** *(model spec)*
- **Given** a CE `game_state` arranged so one player's hand is empty (`game_over?` true)
- **When** I call `game_state.winner`
- **Then** it returns that player (`winner.hand`.empty?; `winner.name` present)

**A2 — the shared example's "reports a winner" now passes for Crazy Eights**
- Remove the `pending` guard; `it_behaves_like 'a persisted card game'` on `CrazyEightsGame`
  goes green (arrange the over-game in the host `before`).

**A3 — C3 system spec: the CE winner screen renders** *(system spec)*
- **Given** a started CE game arranged over and `save!`d
- **When** I `visit winner_game_path(game)`
- **Then** the page shows the winner's name (was `pending`, now green)

> RSpec flags A2/A3 as **FIXED** the instant `winner` is defined and fails until you delete
> the `pending` lines — that's the intended Improvement 1 → 2 handoff firing.

---

## Deliverable B — One game registry (plan item 3)

**Files:** `app/models/game.rb`, `app/views/games/new.html.slim`,
`app/controllers/games_controller.rb`.

**Goal:** a single source of truth for playable types, so the new-game form, the `create`
class lookup, and (later) `build_game` all read from one place instead of hardcoded strings.

**Steps**
1. Add a registry to `Game` — subclass + human label. Suggested shape:
   ```ruby
   PLAYABLE_TYPES = { 'GoFishGame' => 'Go Fish', 'CrazyEightsGame' => 'Crazy Eights' }.freeze

   def self.playable_types
     PLAYABLE_TYPES
   end
   ```
   (A hash keeps class ⇄ label in one literal. If you prefer, expose
   `[[label, type]]` pairs shaped for `simple_form`'s `collection:`.)
2. Drive `new.html.slim:4` from the registry so the collection is no longer the literal
   `['Go Fish', 'Crazy Eights']`. Submit the **class name** (`type`) as the value and show
   the **label** to the user (avoids the `.delete(' ')` string surgery in `create`).
3. Simplify `GamesController#create`: look the class up from the registry
   (`Game.playable_types`) instead of `"#{type}Game".delete(' ').constantize`. Reject a type
   that isn't in the registry (don't `constantize` arbitrary input).
4. Fix `game_params`: drop the dead `:game_type` permit; permit `:name` and `:type`.

**B1 — `Game.playable_types` lists exactly the playable subclasses** *(model spec)*
- **When** I call `Game.playable_types`
- **Then** its keys are exactly `%w[GoFishGame CrazyEightsGame]` (and it includes no base
  `Game` or archived/abstract types)

**B2 — the new-game form renders every registry entry** *(system spec)*
- **Given** I visit `new_game_path`
- **When** the form renders
- **Then** the type select offers every `Game.playable_types` label (add a third registry
  entry temporarily and confirm the option appears — proves it's registry-driven, not
  hardcoded)

**B3 — `create` builds the right subclass from a registry type** *(system spec, likely
already covered)*
- **Given** I submit the new-game form with type "Crazy Eights"
- **Then** a `CrazyEightsGame` is persisted (guard the existing create flow didn't regress)

---

## Deliverable C — Polymorphic `build_game` (plan item 2)

**Files:** `app/models/game.rb`, `app/models/go_fish_game.rb`,
`app/models/crazy_eights_game.rb`.

**Goal:** delete the `if/else` in `Game#build_game` and its silent
"else-is-CrazyEights" trap. Each subclass declares which domain `Game`/`Player` it builds.

**Steps**
1. Give each subclass the pair it needs, e.g.:
   ```ruby
   # GoFishGame
   def build_game
     GoFish::Game.new(users.map { GoFish::Player.new(it.id) })
   end
   ```
   ```ruby
   # CrazyEightsGame
   def build_game
     CrazyEights::Game.new(users.map { CrazyEights::Player.new(it.id) })
   end
   ```
   (Or a `domain_game_class` / `domain_player_class` pair the base `start` uses — pick
   whichever reads clearest; the plan allows either.)
2. Remove `build_game` and the `GO_FISH_GAME_TYPE` branch from the base `Game`. `Game#start`
   still calls `build_game` polymorphically.
3. If you keep `build_game` `private`, ensure both subclass overrides are also `private`.

**C1 — each subclass builds its own domain game** *(model spec)*
- **Given** a `GoFishGame` (resp. `CrazyEightsGame`) with players, started
- **Then** `game_state` is a `GoFish::Game` (resp. `CrazyEights::Game`)

**C2 — an unknown/third type is NOT silently coerced to Crazy Eights** *(model spec — the
regression guard the plan calls for)*
- **Given** a throwaway STI subclass with no `build_game` (define one in the spec)
- **When** I `start` it
- **Then** it does **not** produce a `CrazyEights::Game` — it raises (e.g.
  `NoMethodError`/`NotImplementedError`) rather than silently defaulting
- *This is the whole point of deleting the `else` — assert the trap is gone.*

---

## Deliverable D — Unify the `play_turn` interface (plan item 1)

**Files:** `app/controllers/games_controller.rb`, `app/models/go_fish_game.rb`,
`app/models/crazy_eights_game.rb`; **rewrite** `spec/models/go_fish_game_spec.rb` and
`spec/models/crazy_eights_game_spec.rb` Deliverable A blocks (signature changes).

**Goal:** one polymorphic `play_turn(params)` per subclass so `GamesController#play` is a
single call. Move `play_crazy_eights`'s logic (`games_controller.rb:66-72`) into
`CrazyEightsGame`. Delete the controller `if/else` and the game-specific private method.

**Steps**
1. Change the controller `play` action to one polymorphic call:
   ```ruby
   def play
     @game = Game.find(params[:id])
     redirect_to winner_game_path(@game) and return if @game.game_state.game_over?
     @game.play_turn(params[:play_turn])
     @game.save!
     redirect_to game_path(@game)
   end
   ```
   Delete `play_crazy_eights`.
2. `GoFishGame#play_turn(params)` reads its own shape:
   ```ruby
   def play_turn(params)
     if game_state.current_player.hand_size == 0
       game_state.fish_and_skip
     else
       game_state.play_turn(params[:player].to_i, params[:rank].chars.first)
     end
   end
   ```
   (Note the `rank.chars.first` truncation bug from `AGENTS.md` — a 2-char rank like `'10'`
   becomes `'1'`. **Out of scope here** unless you decide to fix it; if you do, flag it so
   the unification and the bug fix aren't conflated.)
3. `CrazyEightsGame#play_turn(params)` computes `active_card` from its own state (the
   controller no longer passes it):
   ```ruby
   def play_turn(params)
     active_card = game_state.william.active_card
     placed = params[:rank]
     placed.present? ? place_card(active_card, placed) : draw_until_playable(active_card)
   end
   ```
   Move the draw-until-playable loop into a private helper (keep each method ≤ 7 lines).
   The domain `CrazyEights::Game#play_turn(active_card, placed_card)` is unchanged.
4. **Update Improvement 1's Deliverable A specs** — they call the *old* two-positional-arg
   signatures (`game.play_turn(opponent_id, 'Ace')` and `game.play_turn(active_card, placed)`).
   Rewrite them to pass a params hash (`{ player:, rank: }` / `{ rank: }`). Improvement 1
   explicitly pinned those signatures *so this change is caught* — expect these edits.

**D1 — Go Fish: controller `play` delegates via the params hash** *(model + system)*
- **Given** a started Go Fish game
- **When** `game.play_turn(player:, rank:)` (or the play form is submitted)
- **Then** a round result is appended (normal ask) — the A1 behavior, new signature

**D2 — Go Fish: empty hand still takes fish-and-skip** *(model)*
- Re-pin A2 against `play_turn(params)`: empty current hand ⇒ `fish_and_skip` runs

**D3 — Crazy Eights: place a given card via the params hash** *(model)*
- Re-pin A3: `play_turn(rank: '<card>')` ⇒ `william.active_card` becomes that card and the
  turn advances

**D4 — Crazy Eights: draw-until-playable when no card is passed** *(model)*
- Re-pin A4: `play_turn({})` / `play_turn(rank: nil)` ⇒ placed card matches active card's
  suit or rank; William grew by 1; non-matching draws went to the current player's hand

**D5 — the CE turn works end-to-end through the UI** *(system — Improvement 1 C1 guards this)*
- Clicking **Place card** still advances the discard pile and passes the turn (no
  controller `if/else` regression)

---

## Deliverable E — Remove the stray view conditional (plan item 4)

**File:** `app/views/crazy_eights_games/_crazy_eights_game.html.slim:60`.

**Goal:** delete dead code left over from a time this partial rendered both games.

**Steps**
1. Confirm (already verified) that `show.html.slim` uses `= render @game`, so this partial
   only ever renders for a `CrazyEightsGame`.
2. Delete line 60 — the `= f.input :player … if game.type == "GoFishGame"` — entirely. CE
   has no opponent-select; the branch never rendered.
3. Confirm the CE turn form still submits (`:rank`, `:suit`) and Improvement 1's C1 system
   spec stays green.

**E1 — CE partial renders without the player select** *(system — reuse C1)*
- **Given** a started CE game shown to the current player
- **Then** the play form renders (rank/suit, Place card) with no opponent select and no
  reference to `game.type`

---

## Verification for Improvement 2

```sh
bundle exec rspec        # full suite green; the 2 CE-winner pendings are now real passes
bundle exec rspec spec/models/go_fish_game_spec.rb spec/models/crazy_eights_game_spec.rb spec/system/games_spec.rb
bin/rubocop              # clean
```

- **Zero** `type == 'GoFishGame'` / `type == "GoFishGame"` strings remain in
  `app/` (`grep -rn "GoFishGame" app/` should only show class defs / registry keys, no
  branch conditionals).
- The two Improvement 1 `pending` markers are deleted (RSpec no longer reports FIXED/pending
  for CE winner).
- **Regression guard (C2):** a throwaway third STI subclass is *not* coerced into Crazy
  Eights by `build_game`.
- **Manual smoke via `bin/dev`:** create each game from the lobby, start, play a turn, reach
  the winner screen for **both** games (confirms the `winner` fix + polymorphic `play` +
  registry-driven `create`).

## What this sets up (the payoff)

Adding a third game becomes: create `app/models/<name>_game.rb` (serialize coder +
`play_turn(params)` + `build_game`), the `app/models/<name>/` domain namespace, one view
partial (`_<name>_game.html.slim`), and one registry entry in `Game::PLAYABLE_TYPES`. **No
edits to any shared `if/else` branch.** The optional stretch (extract shared `Card`/`Deck`)
in `docs/improvement-plan.md` remains available if time allows.
