# Rummy — Design Handoff

Purpose: bring the **Rummy UI** to life in the real app, then wire it into the STI game
registry and build the real rules engine. Written across two sessions (Sonnet).

## Status / what happened

**Session 1 (planning + design):** static mockup only, no Rails code.
`mockup-html/rummy.html` + `mockup-html/cards/*.svg` remain the **visual source of truth**
(open in a browser, or `python3 -m http.server` from `mockup-html/`) — but the real app now
renders the same design, so reach for that first; the mockup is a fallback reference.

**Session 2 (this one, done): static render in the real app, isolated from the game
registry.** Deliberately scoped narrow — mock data, no `Game::PLAYABLE_TYPES` entry, no
`RummyGame`/`Rummy::*` domain classes, no lobby changes, so nothing here needed specs yet:
- `app/views/pages/rummy_preview.html.slim` — the ported design, driven entirely by hardcoded
  Ruby literals (arrays of card filenames/hashes) at the top of the file. Reachable at
  `/pages/rummy_preview` (real auth required) via `PagesController#rummy_preview` + a route,
  mirroring the existing `pages/rules` pattern.
- One CSS component file per new block under `app/assets/stylesheets/components/`: `meld.css`,
  `pile.css`, `turn-actions.css`, `rummy-turn.css`, `player-row.css`, `feed-drawer.css`. No
  manifest edit needed — resolved the CSS-bundling open question from session 1: Propshaft's
  `stylesheet_link_tag :app` auto-links **every** file under `app/assets/stylesheets`, so a new
  file in `components/` is picked up automatically.
- `playing-card.css` gained `playing-card--flush-border` (removes the double-border artifact
  on **standalone** cards only — see gotchas below), `playing-card--selectable`, `is-selected`.
- The feed drawer (tab/backdrop/slide-in panel) is static — no Stimulus controller yet, by
  design; toggle it manually via `document.body.classList.add('feed-open')` in devtools.
- Ran an accessibility/polish pass (impeccable skill): hover state on the feed tab, real
  Optics tokens throughout instead of hardcoded px/rgba/ms values (see gotchas below).
- **Also renamed the shared 4-panel grid classes app-wide** (Go Fish + Crazy Eights + this
  preview): `panel--players/--feed/--books` → `panel--board/--controls/--aside` (`--hand`
  unchanged). The old names were Go-Fish-specific nouns that didn't fit what Crazy Eights/Rummy
  actually put in those slots. Full RSpec suite passes with the new names.

**Next session (your job): wire the STI registry + real domain, then real turn logic** — see
"Implementation plan" below, steps 1–3 are what's left.

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
`image_tag "generated_cards/#{card.to_pathname}"` rendering. The grid areas (as of the
universal-panel rename — see Status) are `"board controls" / "hand aside"`; we put Rummy
content in each slot:

- **Top-left slot (`game__board` / `panel--board`) → "The Table"** — the shared meld
  collection. Melds flow in a **`flex-direction: row; flex-wrap: wrap`** layout. Each meld = a
  row of card images with a **centered "Lay off here" button** below it (space above the
  button). Melds are table-level/shared, **not per-player** (no accordion).
- **Top-right slot (`game__controls` / `panel--controls`) → turn controls** (the feed itself
  moved to a drawer, see below). Header: **"Draw a card"** (phase text, left) + **"Your Turn"
  badge** (right). Content is **centered vertically and horizontally**: the **Deck + Discard
  piles** (centered row) above a **full-width stacked** button group.
- **Bottom-left slot (`game__hand` / `panel--hand`) → "Your Hand"** — your cards; **cards are
  clickable to select** (see interactions).
- **Bottom-right slot (`game__aside` / `panel--aside`) → "Players"** — a plain list of **name +
  card count** (+ a whose-turn marker). No accordion. (This slot has no consistent role across
  the three games — Go Fish puts "Your Books" here, Crazy Eights the discard pile — hence the
  neutral `aside` name rather than something content-specific.)

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

## Implementation plan

Follow the existing "adding a game" pattern (see `AGENTS.md` "Adding a game" + Go Fish /
Crazy Eights as templates).

**Done (session 2):**
- ~~Step 4, partial~~ — done, but as an **isolated preview**, not the real STI partial: the
  ported markup lives at `app/views/pages/rummy_preview.html.slim`, driven by hardcoded Ruby
  arrays instead of a real domain object. When you build the real partial (step 4 below), port
  this file's structure over and swap the hardcoded arrays for real `Rummy::Game` state — the
  markup itself shouldn't need to change much.
- ~~Step 5, CSS~~ — done, and the bundling question is **resolved**: `stylesheet_link_tag :app`
  (Propshaft) auto-links every file under `app/assets/stylesheets`, no manifest edit needed.
  One file per new component already exists in `components/`: `meld.css`, `pile.css`,
  `turn-actions.css`, `rummy-turn.css`, `player-row.css`, `feed-drawer.css`.

**Still open — start here next session:**

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
     — a discard top, opponents with card counts) — the exact shape already visible in
     `rummy_preview.html.slim`'s hardcoded arrays. Add `find_player`, `current_player`,
     `active_card (= discard_pile.last)`, `stock_size`, `game_over? = false`, `winner = nil`.
   - `Rummy::Player` — mirror `CrazyEights::Player` (id, name, hand, `add_cards`, `self.load`).
   - `Rummy::Meld` — holds `cards` + `self.load`; leave real validation (set/run, aces-low,
     lay-off) as a TODO for the logic phase.
   - Rely on ActiveSupport's default `as_json` for sub-objects (Player/Meld/Card), same as
     the other games; only `Rummy::Game` defines an explicit `as_json`.
   - Serialization round-trips through the `game_state` jsonb, so every field needs
     load/dump coverage — miss one and it silently drops on reload. Smoke-test with
     `bin/rails runner` (build → deal! → dump → `JSON.parse(dump.to_json)` → load).
4. **Real partial** `app/views/rummy_games/_rummy_game.html.slim` — STI resolves `render @game`
   to this path. Port `rummy_preview.html.slim`'s structure over; render the phase-aware
   controls from `drawn_this_turn?` instead of the hardcoded button states. Once this works
   end-to-end from the lobby, retire the `/pages/rummy_preview` route/controller action/view
   — it was scaffolding for the design pass, not meant to stick around.
5. **Verify** by running the app (`bin/dev`) and viewing a created+started Rummy game; the
   demo state should render the full board. Match against the mockup / `rummy_preview`.
6. **Then**, real turn logic: `play_turn(params)` dispatch on `params[:move]`, `Meld`
   validation (set/run, aces-low), lay-off, discard, going-out/scoring — see "Turn contract"
   below for the param shapes already locked in.

## CSS learnings / gotchas discovered while building the mockup

- **Drawer vs. same-green panel**: the feed drawer uses the same green token as the control
  panel; laid directly over it they blend into one flat block. It only reads as a separate
  layer with a **shadow + a small accent edge** (and a dimmed backdrop). Bake that in.
- **Logical properties + vertical writing-mode don't compose**: `writing-mode: vertical-rl`
  swaps which axis is "block" vs. "inline", so logical properties round/space the **wrong**
  side. *Logical* `border-start-start-radius` etc. rounded the top instead of the inward-facing
  left edge; `margin-block-start` (meant to add space *below* the tab's dot) shifted it
  *sideways* instead, since block-start is now horizontal. Use **physical** properties
  (`border-top-left-radius`/`border-bottom-left-radius`, `margin-top`) on rotated-text elements.
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

- The pre-existing **card-corner border quirk** (double rounded outline on `.playing-card`) —
  **partially fixed** in the preview build: `.playing-card--flush-border` (zeroed
  border/radius, since the card SVG already draws its own frame) is applied to the standalone
  Deck/Discard pile images. **Not** applied to melds/hand — those fan cards with overlapping
  negative margins, and removing the outer border there made the overlap seams look worse, not
  better. Full fix (or a different approach for the fanned case) is still open.
- Real turn logic, `Meld` validation, scoring, winner detection.
- **Game-over persistence** (`Game#end`/`ended_at` + `players.winner` boolean) — a known
  deferred High finding; when Rummy's real scoring is built, do this as a **game-agnostic**
  change so all three games write end state. Not part of the mock-data task.
