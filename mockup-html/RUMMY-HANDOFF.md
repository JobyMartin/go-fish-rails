# Rummy — Design Handoff

Purpose: implement the **Rummy UI** into the real app **with mock data** (no real game
logic yet), matching the static mockup. Written for a fresh session (Sonnet).

## Status / what happened this session

- This was a **planning + design** session. **No real Rails code was changed** — an earlier
  stub implementation was built and then **fully reverted** at the user's request.
- The only committed artifact is the **static mockup**: `mockup-html/rummy.html` +
  `mockup-html/cards/*.svg`. That file is the **visual source of truth** — open it in a
  browser (or `python3 -m http.server` from `mockup-html/`) to see the target design.
- Next step (your job): build the real `rummy_games/_rummy_game.html.slim` partial + a
  **stub domain** that seeds mock data, so the design renders in the actual app.

## The game we're adding

Standard Rummy ("Rum"), 2–6 players. Source: assignment brief + bicyclecards.com/rummy-rum.

**Rules / variant choices:**
- Aces low only (A-2-3 valid; Q-K-A not). Ace pips = 1.
- Melds: **sets** (3–4 same rank) and **runs** (3+ consecutive, same suit).
- Deal: 2p → 10 cards, 3–4p → 7, 5–6p → 6. Rest = **deck** (draw pile); top card flips to
  start the **discard pile**.
- Turn (multi-step, in order): **draw** one (from deck OR discard) → optional **meld / lay
  off** (any number; lay off onto anyone's melds) → **discard** one (ends turn).
- Going out = empty hand after discard → hand ends. Score everyone else's leftover pips
  (face=10, ace=1, else face value); **lowest wins**.

**Scope decisions locked:**
- A game = a **single hand** (no play-to-target across hands).
- Turn = **separate request per phase** (draw/meld/layoff/discard); stays on `rack_test`, no
  mandatory JS for the turn itself.
- Going-out "rummy" double-score bonus: **out of scope**.
- "Can't discard the card you just drew from discard": nice-to-have, not MVP.

## Layout — "Variant 1" mapped onto the existing four-panel `.game` grid

Reuse the shared `.game` grid + `.panel`/`.panel--*` + `.playing-card` classes and the
`image_tag "generated_cards/#{card.to_pathname}"` rendering. The grid areas stay
`"players feed" / "hand books"`; we just put Rummy content in each slot:

- **Top-left slot (`game__players`) → "The Table"** — the shared meld collection. Melds flow
  in a **`flex-direction: row; flex-wrap: wrap`** layout. Each meld = a row of card images
  with a **centered "Lay off here" button** below it (space above the button). Melds are
  table-level/shared, **not per-player** (no accordion).
- **Top-right slot (`game__feed`) → turn controls** (the feed itself moved to a drawer, see
  below). Header: **"Draw a card"** (phase text, left) + **"Your Turn" badge** (right).
  Content is **centered vertically and horizontally**: the **Deck + Discard piles** (centered
  row) above a **full-width stacked** button group.
- **Bottom-left slot (`game__hand`) → "Your Hand"** — your cards; **cards are clickable to
  select** (see interactions).
- **Bottom-right slot (`game__books`) → "Players"** — a plain list of **name + card count**
  (+ a whose-turn marker). No accordion.

## The slide-out feed drawer

The narrative feed does **not** live inline (it crammed the control panel). Instead:
- A thin vertical **"Game Feed" tab** rides the **right edge** (with an unread dot).
- Clicking it slides a **drawer in from the right** (over the board, board dims behind);
  an **×** or the backdrop closes it.
- In the real app: reuse the existing `.feed-content` markup inside the drawer; the feed
  already updates live via `turbo_stream_from @game`, so it stays current while closed (the
  unread dot can reflect that). Build the toggle as a **small Stimulus controller** (the
  mockup uses vanilla JS; the app convention is Stimulus — see existing `timer`,
  `offline-alert`, `service-worker` controllers). This drawer is **Rummy-only**; Go Fish /
  Crazy Eights keep their inline feed.

## Turn phases & controls (server-rendered, no phase JS)

Render controls from domain state — no client-side phase tracking:
- **Not your turn** → all controls disabled.
- **Your turn, haven't drawn** (`drawn_this_turn? == false`) → Deck/Discard draw buttons
  active; header text "Draw a card"; Meld/Discard buttons disabled.
- **Your turn, have drawn** → draw disabled; hand cards selectable; Meld/Discard active;
  header text "Meld or discard".

## Interactions

- **Card selection = click the card** (checkboxes were removed). Selected card gets a
  **green border + box-shadow ring + slight lift** (`.is-selected` in the mockup). MVP: a
  Stimulus controller toggles selection and collects the chosen card ids into a hidden field.
- **Lay off**: each table meld carries its own **"Lay off here"** button (target is
  unambiguous). One card at a time for MVP.

## Turn contract / param shapes (for when real logic is built later — not this task)

All phases post to the existing `play_game_path` (`GamesController#play` → `@game.play_turn`)
with a `move` discriminator. `RummyGame#play_turn(params)` dispatches on `params[:move]`;
`Rummy::Game` holds per-turn state (`drawn_this_turn?`) and only `switch_turns` on discard.
The other two games ignore the new param — **no shared `if/else`**; phase branching lives
inside Rummy.

| Phase   | Control            | Params                                  |
|---------|--------------------|-----------------------------------------|
| Draw    | Deck / Take discard| `move=draw, source=deck\|discard`       |
| Meld    | select cards + Meld| `move=meld, card_ids=[…]`               |
| Lay off | per-meld button    | `move=layoff, meld_id, card_id`         |
| Discard | select one + Discard | `move=discard, card_id`               |

Keeping the meld param as `card_ids[]` means the click-select UI is a drop-in with no
server/spec change.

## Implementation plan for THIS task (mock-data render in the real app)

Follow the existing "adding a game" pattern (see `AGENTS.md` "Adding a game" + Go Fish /
Crazy Eights as templates). You are building a **stub that renders the design**, not the
rules engine.

1. **`Game::PLAYABLE_TYPES`** (`app/models/game.rb`): add `'RummyGame' => 'Rummy'`.
   Update the pinning spec `spec/models/game_spec.rb` (`.playable_types`) to include it.
2. **`RummyGame < Game`** (`app/models/rummy_game.rb`): `serialize :game_state, coder:
   Rummy::Game`; `build_game` returns `Rummy::Game.new(users.map { Rummy::Player.new(it.id) })`;
   `play_turn(params)` can be a **no-op stub** for now.
3. **Domain stubs** under `app/models/rummy/`:
   - `Rummy::Game` — implement the coder contract (`self.load`/`self.dump`/`as_json`/
     `self.from_json`) like `CrazyEights::Game`. Hold `players, deck, current_player_index,
     round_results, melds, discard_pile, drawn_this_turn`. `deal!` **seeds fixed demo state**
     (a nice hand, several melds — mix of sets & runs incl. a 4-card run and a four-of-a-kind
     — a discard top, opponents with card counts). Add `find_player`, `current_player`,
     `active_card (= discard_pile.last)`, `stock_size`, `game_over? = false`, `winner = nil`.
   - `Rummy::Player` — mirror `CrazyEights::Player` (id, name, hand, `add_cards`, `self.load`).
   - `Rummy::Meld` — holds `cards` + `self.load`; leave real validation (set/run, aces-low,
     lay-off) as a TODO for the logic phase.
   - Rely on ActiveSupport's default `as_json` for sub-objects (Player/Meld/Card), same as
     the other games; only `Rummy::Game` defines an explicit `as_json`.
   - Serialization round-trips through the `game_state` jsonb, so every field needs
     load/dump coverage — miss one and it silently drops on reload. Smoke-test with
     `bin/rails runner` (build → deal! → dump → `JSON.parse(dump.to_json)` → load).
4. **Partial** `app/views/rummy_games/_rummy_game.html.slim` — port the mockup's structure
   into Slim (STI resolves `render @game` to this path). Reuse existing classes; render the
   phase-aware controls from `drawn_this_turn?`.
5. **CSS** — the new bits (melds `flex-wrap` row, centered/spaced lay-off buttons, centered
   control panel, clickable-card `.is-selected`, the feed drawer + edge tab) need to go where
   the app actually bundles component CSS. ⚠️ **Open question:** the bundling path is unclear
   — `stylesheet_link_tag :app`, Propshaft, an **empty** `application.scss` manifest, and a
   `webpack.config.js` that isn't what `bin/dev` runs (`bin/dev` runs esbuild via `yarn
   build`, JS only). The existing `components/*.css` (game.css, panel.css, playing-card.css)
   **are** applied in the running app, so trace how before adding a new component file.
   The mockup **inlines copies** of those component styles — do **not** copy that approach
   into the app; add a real `components/rummy.css` (or wherever the trail leads) instead.
6. **Verify** by running the app (`bin/dev`) and viewing a created+started Rummy game; the
   demo state should render the full board. Match against the mockup.

## CSS learnings / gotchas discovered while building the mockup

- **Drawer vs. same-green panel**: the feed drawer uses the same green token as the control
  panel; laid directly over it they blend into one flat block. It only reads as a separate
  layer with a **shadow + a small accent edge** (and a dimmed backdrop). Bake that in.
- **Logical radius + vertical writing-mode don't compose**: the edge tab uses
  `writing-mode: vertical-rl`; using *logical* `border-start-start-radius` etc. rounded the
  **wrong** corners (top instead of the inward-facing left edge). Use **physical**
  `border-top-left-radius` / `border-bottom-left-radius` on rotated-text elements.
- **First-card overlap margin breaks centering**: `.playing-card` has a negative
  `margin-inline-start` (to fan/overlap). On the *first* card of a row it just shifts the
  whole row left of its layout box, so a centered button below looks off-center. **Zero the
  first card's `margin-inline-start`** (per meld) so centering lines up. (Piles already do
  this via `.pile img { margin-inline-start: 0 }`.)
- **Fixed edge tab overlaps panel controls**: full-width right-column buttons got clipped
  under the fixed "Game Feed" tab. Solve with symmetric horizontal padding on the control
  panel content (reserves tab clearance and keeps the group centered), and a **single-column
  full-width button stack** rather than a 2-wide grid in the narrow panel.
- **Naming**: the draw pile is labeled **"Deck"** (not "Stock") — label under the pile and
  on the button ("Draw deck").

## Deferred / out of scope (don't do now)

- The pre-existing **card-corner border quirk** (double rounded outline on `.playing-card`)
  — an implementation-phase cleanup, not a mockup concern.
- Real turn logic, `Meld` validation, scoring, winner detection.
- **Game-over persistence** (`Game#end`/`ended_at` + `players.winner` boolean) — a known
  deferred High finding; when Rummy's real scoring is built, do this as a **game-agnostic**
  change so all three games write end state. Not part of the mock-data task.
