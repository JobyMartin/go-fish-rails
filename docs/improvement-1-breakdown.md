# Improvement 1 — Step-by-Step: "Lock the shared game contract with tests"

> Source: `docs/improvement-plan.md` → *Improvement 1 (do first)*.
> This is **tests-only** work. You are **characterizing existing behavior** so the
> Improvement 2 refactor is safe, and closing the biggest test gap (the shared
> infrastructure every new game builds on). Do **not** change app code in this improvement
> — with one deliberate exception noted under the winner bug below.

## Guiding rule for this improvement

Every spec here should be **green against the code as it exists today**. Where current code
is broken (the `CrazyEights::Game#winner` bug), we *document* the gap with a `pending`
marker rather than fixing it — the fix belongs to Improvement 2. RSpec will automatically
flag the pending example as "fixed" the moment Improvement 2 makes it pass, which is a
clean handoff signal.

Conventions to honor (from `AGENTS.md`): ≤ 7 lines per `it` block, no `@` ivars in specs,
Ruby's implicit block param `it`, TDD/system-spec-first mindset. System specs run under
`rack_test` unless tagged `:js`/`:chrome`.

---

## Progress

- ✅ **A. STI subclass specs** — done. Both branches of each game's `play_turn` are pinned
  in `spec/models/go_fish_game_spec.rb` (A1 normal ask, A2 fish-and-skip) and
  `spec/models/crazy_eights_game_spec.rb` (A3 place a given card, A4 draw-until-playable).
- ✅ B. Serialization round-trip specs
- ✅ D. Shared example (`"a persisted card game"`) — winner clause included, CE marked `pending`
- ✅ C. System specs (winner / game-over) — Go Fish winner screen via `winner_game_path`;
  Crazy Eights winner screen `pending` on the undefined `CrazyEights::Game#winner`

**Improvement 1 complete.** The two model specs + shared example + system specs are green
(4 pending: 2 deliberate CE `winner` handoff markers, 2 pre-existing). Next: Improvement 2
adds `CrazyEights::Game#winner` and replaces the STI type-branching — those pending markers
will flip to FIXED as the handoff signal.

## Order of work

Do them in this order — each builds confidence for the next:

1. **A. STI subclass specs** (`play_turn` branches) — smallest, pure unit-ish, no UI.
2. **B. DB serialization round-trip specs** — proves the `serialize` coder for both games.
3. **D. Shared example** (`"a persisted card game"`) — extract the common contract; reuse
   what you learned in A + B.
4. **C. System specs** — the end-to-end winner/game-over gaps (hardest; needs game-state
   arrangement). Do last so the model-level contract is already pinned.

(The plan lists these as A, B, C, D; C is sequenced last here because it's the fiddliest.)

---

## Getting started (do this first)

```sh
bundle exec rspec spec/models/go_fish_game_spec.rb spec/models/crazy_eights_game_spec.rb spec/system/games_spec.rb
```

Confirm the current baseline: the two model specs are empty `pending` stubs, and
`spec/system/games_spec.rb:304` (`'when the game is over'`) is
`pending: 'broken and cannot figure out'`. Then:

```sh
mkdir -p spec/support/shared_examples
```

Reference facts you'll need (already verified in the codebase):

- Factory `:game` defaults to `type { 'GoFishGame' }` and uses a **polymorphic
  `initialize_with`** (`spec/factories/games.rb`). Create a CE game with
  `create(:game, type: 'CrazyEightsGame')`. Add players with
  `create(:player, user:, game:)`.
- `Game#start` sets `started_at`, calls `build_game`, then `game_state.deal!`, then
  `save!`. So after `game.start; game.save!` a persisted game has a dealt `game_state`.
- `GoFishGame#play_turn(inquired_player_id, inquired_rank)` — if
  `current_player.hand_size == 0` it calls `game_state.fish_and_skip`, else
  `game_state.play_turn(id, rank.chars.first)`.
- `CrazyEightsGame#play_turn(active_card, placed_card = nil)` — with `placed_card` it
  places directly; without it, it **draws from the deck until a playable card appears**,
  keeps that as the placed card, and adds the rest to the current player's hand.
- `GoFish::Game#game_over?` ⇒ `deck.empty? && players.all? { it.hand.empty? }`.
  `CrazyEights::Game#game_over?` ⇒ `players.any? { it.hand.empty? }`.
- **`CrazyEights::Game` does NOT define `winner`** (only `GoFish::Game` does). This is the
  latent bug `GamesController#winner` trips over.

---

## Deliverable A — STI subclass specs

**Files:** `spec/models/go_fish_game_spec.rb`, `spec/models/crazy_eights_game_spec.rb`
(replace the `pending` stubs).

**Goal:** pin each subclass's `play_turn` dispatch — the branch logic that lives on the AR
subclass (not the domain object).

### A1 — `GoFishGame#play_turn` delegates a normal ask

- **Given** a started `GoFishGame` whose current player has at least one card of a known
  rank, and an opponent holding that rank
- **When** I call `game.play_turn(opponent_id, 'Ace')`
- **Then** the domain `game_state.play_turn` runs (cards move / a round result is
  appended), i.e. `game_state.round_results` grows by 1

### A2 — `GoFishGame#play_turn` takes the fish-and-skip branch on an empty hand

- **Given** a started `GoFishGame` whose `current_player.hand` is emptied to size 0
- **When** I call `game.play_turn(anything, anything)`
- **Then** `game_state.fish_and_skip` is exercised — the current player draws a card
  (hand size becomes 1) and a "No rank in question" round result is recorded
- *Tip:* set `game.game_state.current_player.hand = []` after `start`, then assert. You can
  also assert with a message expectation (`expect(game.game_state).to receive(:fish_and_skip)`)
  if you prefer to characterize the dispatch rather than the effect — pick one, keep it ≤7 lines.

### A3 — `CrazyEightsGame#play_turn` places a given card

- **Given** a started `CrazyEightsGame` and a specific `placed_card` string (e.g. matching
  the current `william.active_card` suit/rank)
- **When** I call `game.play_turn(active_card, placed_card)`
- **Then** the card is objectified and placed: `game_state.william.active_card` becomes
  that card and the current player advances (`current_player_index` changes)

### A4 — `CrazyEightsGame#play_turn` draws until a playable card when none is passed

- **Given** a started `CrazyEightsGame` and the current `william.active_card`
- **When** I call `game.play_turn(active_card)` (no `placed_card`)
- **Then** a card is placed onto William that matches the active card's suit or rank, and
  any non-matching cards drawn along the way were added to the current player's hand
  (hand size increased by the number of skipped draws)
- *Tip:* this branch reads the real shuffled deck, so assert on the **invariant** (placed
  card matches suit or rank; William grew by 1) rather than an exact card.

---

## Deliverable B — DB serialization round-trip specs

**Where:** add to the same two subclass spec files (a `describe 'serialization'` /
`'game_state round-trip'` block), OR fold into the shared example (Deliverable D) — the
shared example is the better long-term home, so you may write B *as* the round-trip section
of D. Either is fine; don't duplicate.

**Goal:** prove the `serialize :game_state, coder:` mechanism preserves **fidelity**, not
just presence. This is the platform's core teaching goal and today is only asserted as
"present after reload."

### B1 — Go Fish game_state survives a persist → reload with fidelity

- **Given** a persisted `GoFishGame` that has been `start`ed and played one turn, then
  `save!`d
- **When** I `game.reload` (forcing a fresh load through the `GoFish::Game` coder)
- **Then** the reloaded `game_state` matches the pre-reload state for: each player's hand
  (ranks + suits), `deck` size, `round_results` count/content, and `current_player_index`
- *Tip:* capture `before = game.game_state.as_json` before reload and compare to
  `game.reload.game_state.as_json`. Comparing the `as_json` hashes is the cleanest fidelity
  check and keeps the block short.

### B2 — Crazy Eights game_state survives a persist → reload with fidelity (incl. William)

- **Given** a persisted `CrazyEightsGame`, `start`ed, one turn played, `save!`d
- **When** I `game.reload`
- **Then** the reloaded `game_state` matches for hands, `deck` size, `round_results`, and
  **`william`** (the discard pile / `william.active_card`) and `current_player_index`
- *Tip:* William is the CE-specific field — assert it explicitly so a future coder change
  that drops it fails loudly.

### B3 — a fresh, unstarted game serializes as blank

- **Given** a persisted game that has **not** been started (`game_state` nil/blank)
- **When** I `game.reload`
- **Then** `game_state` loads back as nil (characterizes the `load` guard
  `return if json.blank?`)

---

## Deliverable D — shared example: `it_behaves_like "a persisted card game"`

**File (new):** `spec/support/shared_examples/persisted_card_game.rb`

**Goal:** codify the informal domain interface **both** games already honor, so a third
game gets a ready-made contract to satisfy. Wire in both subclasses.

Contract to assert (from the plan): `deal!`, `find_player`, `current_player`, `players`,
`round_results`, `game_over?`, `winner`, and a clean serialize → reload round-trip.

**Shape:** the shared example takes a game via a `let`/parameter the including spec
provides. Suggested skeleton:

```ruby
# spec/support/shared_examples/persisted_card_game.rb
RSpec.shared_examples 'a persisted card game' do
  # Expects the host to define `game` (a persisted, started AR Game subclass).
  it 'deals cards to every player' do
    expect(game.game_state.players).to all(satisfy { it.hand.any? })
  end

  it 'finds a player by user id' do
    player = game.game_state.players.first
    expect(game.game_state.find_player(player.id)).to eq player
  end

  it 'exposes the current player' do
    expect(game.game_state.current_player).to be_present
  end

  it 'answers game_over?' do
    expect(game.game_state.game_over?).to be_in [true, false]
  end

  it 'round-trips game_state through the DB with fidelity' do
    before_json = game.game_state.as_json
    expect(game.reload.game_state.as_json).to eq before_json
  end
end
```

Then wire both games in — in `go_fish_game_spec.rb` and `crazy_eights_game_spec.rb`:

```ruby
describe 'shared contract' do
  let(:game) { create(:game, type: 'GoFishGame') }        # or 'CrazyEightsGame'
  before { create(:player, game:); create(:player, game:); game.start; game.save! }

  it_behaves_like 'a persisted card game'
end
```

### The `winner` and `round_results` parts of the contract — a decision point

The plan lists `winner` as part of the contract "both games already honor." **They don't:**
`CrazyEights::Game` has no `winner` method (that's the known bug). If you assert `winner`
in the shared example, the Crazy Eights inclusion goes **red**, which conflicts with the
"green suite" verification target for this improvement.

**Recommended path (keeps Improvement 1 green, documents the gap):**

- Put the `winner` assertion in the shared example, but guard the CE inclusion so it's
  explicitly `pending`:

  ```ruby
  it 'reports a winner' do
    pending 'CrazyEights::Game#winner is undefined — fixed in Improvement 2' if game.is_a?(CrazyEightsGame)
    expect(game.game_state.winner).to be_present   # arrange an over game in the host `before`
  end
  ```

  When Improvement 2 adds `CrazyEights::Game#winner`, RSpec reports this pending example as
  **"FIXED"** and fails the run until you remove the `pending` line — an automatic, visible
  handoff. `round_results` is safe to assert directly (both games maintain it).

Confirm the direction on the winner handling before you commit to it (see the question at
the end of this doc).

---

## Deliverable C — system specs (the real end-to-end gaps)

**File:** extend `spec/system/games_spec.rb`. System specs are the repo's **primary**
coverage mechanism.

Note what already exists so you don't duplicate:
- Go Fish create + start + play-a-turn: covered (`'when the user plays a turn'`).
- Crazy Eights create + show render + a *minimal* "place card" turn: covered
  (`'when the user plays a turn' → 'shows the turn in the turn results'`).

The genuine gaps are **winner / game-over for both games**.

### C1 — Crazy Eights: playing a turn advances the game (strengthen existing coverage)

The existing CE turn test only asserts a feed entry appears. Add depth:

- **Given** a started Crazy Eights game shown to the current player
- **When** they click **Place card**
- **Then** the discard pile (William) reflects the newly placed card **and** the turn
  passes to the next player (assert on visible turn/feed state)
- *Keep it ≤ 7 lines; assert one or two observable outcomes.*

### C2 — Go Fish: the winner / game-over screen (replaces the broken `pending` block)

The block at `spec/system/games_spec.rb:304` is `pending: 'broken and cannot figure out'`.
The reason it was flaky: `GamesController#play` checks `game_over?` **before** playing, so
the turn that *causes* game-over still redirects to the game page — you only reach the
winner screen on a *subsequent* request against an already-over game. So arrange an
**already-over** game and hit the winner path directly.

- **Given** a started Go Fish game whose `game_state` is arranged to be over
  (`deck.cards = []` and both players' hands emptied, or arranged so
  `game_state.game_over?` is true) and `save!`d
- **When** I `visit winner_game_path(game)` (the `winner` action + `winner.html.slim`)
- **Then** the page shows the winner (`expect(page).to have_content 'winner'` or the
  winning player's name)
- *Tip:* `visit winner_game_path(game)` exercises the exact controller path
  (`@game.game_state.winner`) end-to-end under `rack_test`. Alternatively drive it through
  the UI: arrange an already-over game, `visit game_path`, click the play button, and the
  controller's `redirect_to winner_game_path and return if game_over?` takes you there.

### C3 — Crazy Eights: the winner / game-over screen (surfaces the bug)

- **Given** a started Crazy Eights game arranged so `game_state.game_over?` is true (empty
  one player's hand) and `save!`d
- **When** I `visit winner_game_path(game)`
- **Then** (desired) the page shows the winner — but **today this raises `NoMethodError`**
  because `CrazyEights::Game#winner` is undefined
- **Action:** write the spec, then mark it
  `pending: 'CrazyEights::Game#winner undefined — fixed in Improvement 2'`. This documents
  the exact gap and auto-flags when Improvement 2 fixes it. Do **not** patch the app here.

---

## Verification for Improvement 1

```sh
bundle exec rspec spec/models/go_fish_game_spec.rb spec/models/crazy_eights_game_spec.rb spec/system/games_spec.rb
bundle exec rspec spec/support/shared_examples   # if you factored round-trip into D
bin/rubocop
```

Expect: **green**, with the CE `winner` examples reported as `pending` (not failing). No
app-code changes except — if you choose — none at all (recommended). When you later run
Improvement 2, those pending examples should flip to passing and RSpec will tell you to
remove the `pending` markers.

## What this sets up for Improvement 2

- The subclass `play_turn` specs (A) pin the two different signatures **before** you unify
  them into one polymorphic `play_turn(params)`.
- The round-trip specs (B) + shared example (D) guarantee the `serialize` coder keeps
  working as you push `build_game` onto the subclasses.
- The winner system specs (C2/C3) are the safety net for the `CrazyEights::Game#winner`
  fix and the `create`/`play` type-dispatch removal.

---

## One decision I need from you

The plan lists `winner` as a contract "both games already honor," but `CrazyEights::Game`
doesn't define it — that's the latent bug. I've recommended keeping Improvement 1 strictly
tests-only and marking the CE `winner` examples `pending` (green suite, auto-flags on fix).
The alternative is to make the one-line `winner` fix now so the shared example is fully
green without any pending markers. My recommendation is the `pending` route (keeps the
tests → refactor split clean), but confirm before implementing.
```

