# BRAVE Breakdown: Add Rummy to the Game Platform (STI wiring, no logic)

> **Status: complete, and this is a historical planning record — read
> `docs/games/rummy.md` for current state.** Everything below describes Rummy as scoped *at
> the time*, so several notes are deliberately no longer true: `Meld` validation is no longer
> "a TODO", `game_over?` is no longer hardcoded `false`, and `play_turn` is no longer a stub.

> Scope note from planning: **this is a platform/STI card, not a view card.** The show-page
> fidelity — porting the `rummy_preview` design, curated demo melds/hand, feed drawer,
> selection JS — is explicitly **out of scope** and belongs to a later card. This card proves
> the platform treats Rummy as a first-class game *type*.

## Brainstorm

**What the work is:** Make Rummy a real, registered, selectable game so the platform can
create, start, deal, persist, and reload it exactly like Go Fish and Crazy Eights — with
**no real turn logic** (`play_turn` is a no-op stub; no set/run/meld/lay-off/scoring).

**Scope decisions locked (this card):**
- **Pure platform wiring** — no gameplay behavior.
- **No view work.** A **minimal placeholder partial** must exist only because STI resolves
  `render @game` to `rummy_games/_rummy_game`; without it a started Rummy game's show page
  500s. Content fidelity does not matter — the real design port is a separate later card.
- **No JS.** Feed-drawer toggle and click-to-select become their own cards in the logic phase
  (nothing for them to drive while `play_turn` is inert).
- **Minimal domain to satisfy the coder contract.** `Rummy::Game` / `Rummy::Player` /
  `Rummy::Meld` exist and round-trip through the `game_state` jsonb; `deal!` deals cards so
  `start` works and every field survives reload. **No curated demo melds.**

**Real-world scenario:** A signed-in user opens the lobby, sees **Rummy** in the game-type
dropdown, creates a "New Rummy game", another user joins, the creator starts it. The platform
builds a `Rummy::Game`, deals, serializes to jsonb, and the show page renders the placeholder
partial without error. Reloading the page reloads identical state from the column.

**Ambiguity resolved:** "the overall addition of Rummy" initially read as including the view
port; clarified to mean the **STI/platform layer only**. The demo-state-vs-real-players
question is therefore moot for this card.

## Approach

Follow the existing **"adding a game"** pattern verbatim (AGENTS.md); Crazy Eights is the
closest template. No new patterns introduced.

1. **Registry** (`app/models/game.rb`): add `'RummyGame' => 'Rummy'` to `PLAYABLE_TYPES`.
   This is the single lever — the lobby dropdown (`games/new.html.slim:4`) and the system
   spec (`games_spec.rb:73`) both read `Game.playable_types` **dynamically**, so the lobby and
   that select-options assertion light up for free. Only the **pinning spec**
   (`game_spec.rb:40`) hard-codes the hash and must be updated.
2. **`RummyGame < Game`** (`app/models/rummy_game.rb`), mirroring `CrazyEightsGame`:
   - `serialize :game_state, coder: Rummy::Game`
   - `build_game` → `Rummy::Game.new(users.map { Rummy::Player.new(it.id) })` (private)
   - `play_turn(params)` → **no-op stub** (documented as intentionally inert).
3. **Domain stubs** under `app/models/rummy/`, mirroring `CrazyEights::*`:
   - `Rummy::Game` — the full coder contract (`self.load`/`self.dump`/`as_json`/`self.from_json`),
     `attr_accessor :players, :deck, :current_player_index, :round_results, :melds,
     :discard_pile, :drawn_this_turn`. Accessors: `find_player`, `current_player`,
     `active_card (= discard_pile.last)`, `stock_size`/`deck` size, `game_over? = false`,
     `winner = nil`. `deal!` deals per Rummy counts (2p→10, 3–4p→7, 5–6p→6) — a *deal*, not
     *turn logic* — and flips one card to `discard_pile`; `melds` starts `[]`.
   - `Rummy::Player` — copy `CrazyEights::Player` (id, name default, hand, `add_cards`, `self.load`).
   - `Rummy::Meld` — holds `cards` + `self.load`; **validation is a TODO** for the logic phase.
   - Sub-objects (Player/Meld/Card) lean on ActiveSupport's default `as_json`; only
     `Rummy::Game` defines an explicit `as_json` — same as the other two games.
4. **Reuse** the top-level `Card`/`Deck` (bare refs inside `module Rummy` resolve via constant
   lookup, per Card 2). Reuse `RoundResult`/`RoundFeed` shape only if trivially free —
   otherwise `round_results` is an empty array that round-trips.
5. **Placeholder partial** `app/views/rummy_games/_rummy_game.html.slim` — smallest thing that
   renders without error (e.g. a heading + "Rummy coming soon"). Not the design port.
6. **Factory** `spec/factories/rummy_games.rb` mirroring `crazy_eights_games.rb`.

**Initial spike / mid-way check:** after steps 1–3, smoke-test serialization in isolation
(the handoff's recipe) — `bin/rails runner` → build → `deal!` → `dump` →
`JSON.parse(dump.to_json)` → `load`, assert nothing dropped. Green here means the risky part
is done before any spec ceremony.

**Error/recovery states:** none added — inert controls, no user actions to fail. The one
guard already in place (`require_participation`) covers Rummy for free since it's game-agnostic.

## Value

- **Business/teaching value:** demonstrates that the Improvement-2 polymorphic design pays off
  — a third game slots in via **one registry entry + a coder subclass + a domain namespace**,
  with **no shared `if/else` touched**. That's the whole point of the refactor round; this card
  is its proof.
- **User value:** Rummy appears in the lobby and is creatable/startable end-to-end — a visible
  milestone even before gameplay.
- **Priority:** essential *foundation* for the Rummy phase — steps 6+ (real turn logic) and the
  design port both build on this. Nothing else can proceed until the type exists.
- **Optimize for:** **quality + learning.** Serialization correctness is the teaching core and
  the main failure mode; get the round-trip airtight rather than rushing.

## Estimate

**Size: Medium — ~8 points (~1 day).** With the 15% review/pairing buffer, still comfortably
Medium. Most of the effort is the domain stubs + comprehensive serialization coverage, not the
wiring (which is minutes).

**Suggested pairing:** light. A short pairing/review checkpoint after the serialization spike
(step 3) is the highest-value moment — that's where a dropped field would hide.

**Top risks:**
| Risk | Likelihood | Severity | Mitigation |
|------|-----------|----------|------------|
| A `game_state` field silently drops on reload (missing from `as_json`/`from_json`) | Medium | Low | Round-trip spec + `bin/rails runner` smoke test; use the shared **"a persisted card game"** example |
| Deck/discard construction order consumes cards at init (like `William.new([deck.top_card])`) and breaks reload | Low–Med | Low | Cover with the round-trip spec; keep `deal!` the only place that moves cards |
| Placeholder partial references state/helpers that don't exist → show page 500 | Low | Low | System spec that starts a Rummy game and asserts the page loads |
| `game_over? = false` forever → status stuck "In progress", never archived-as-finished | Low | Low | Acceptable/known; real scoring + game-over persistence is a deferred game-agnostic card |

**Incremental shipping:** steps 1–3 + the placeholder partial are the natural shippable
increment (Rummy is registered, creatable, startable, persistent). The real design port is
*already* a separate future card, so this card is essentially the minimum increment.

**Dependencies / sequencing:** unblocked — Improvements 1 & 2 and Cards 1–3 are all complete;
top-level `Card`/`Deck` already exist. This card **must land before** the design port (step 4
in the handoff) and before real turn logic (step 6).

## Implementation Plan (TDD, outside-in)

- [ ] **System spec (red first):** in `spec/system/games_spec.rb`, a user creates a **Rummy**
      game from the lobby, a second joins, creator starts it, and the show page loads without
      error. (The existing dropdown-options assertion at :73 covers itself once the registry
      changes.)
- [ ] **Registry:** add `'RummyGame' => 'Rummy'` to `Game::PLAYABLE_TYPES`; update the pinning
      spec `game_spec.rb` (`.playable_types` expected hash).
- [ ] **`RummyGame` STI spec** (`spec/models/rummy_game_spec.rb`) mirroring
      `crazy_eights_game_spec.rb`: builds a `Rummy::Game`, `play_turn` is an inert no-op.
- [ ] **`RummyGame < Game`:** `serialize` coder, private `build_game`, no-op `play_turn`.
- [ ] **Domain specs** (`spec/models/rummy/{game,player,meld}_spec.rb`) + the shared
      **"a persisted card game"** round-trip example for `RummyGame`.
- [ ] **`Rummy::Player`**, **`Rummy::Meld`**, **`Rummy::Game`** (coder contract, accessors,
      `deal!`, `game_over? = false`, `winner = nil`).
- [ ] **Serialization smoke test** via `bin/rails runner` (build → deal! → dump → parse → load).
- [ ] **Factory** `spec/factories/rummy_games.rb`.
- [ ] **Placeholder partial** `app/views/rummy_games/_rummy_game.html.slim`.
- [ ] **Green gate:** full `bundle exec rspec` + `bin/rubocop`.

---

*Reflect artifact suggestion:* a one-line **data-shape sketch** of the `game_state` jsonb for
Rummy (which keys `as_json` writes and `from_json` reads back) would make the serialization
contract easy to confirm at the pairing checkpoint — that's the card's one place with real
risk.
