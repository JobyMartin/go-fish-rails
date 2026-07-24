# Rummy

Standard Rummy ("Rum"), 2–6 players. Wired into the STI registry and lobby like Go Fish
and Crazy Eights; real turn logic (draw/meld/lay off/discard) is implemented.

## Rules

- **Aces low only**: `A-2-3` is a valid run; `Q-K-A` is not.
- **Melds**: **sets** (3–4 cards, same rank) and **runs** (3+ consecutive ranks, same suit,
  no upper bound).
- **A turn**: **draw** one card (from the deck or the discard pile) → optional **meld**/
  **lay off** (any number, onto your own or anyone's table melds) → **discard** one (ends
  the turn).
- **Must meld before laying off.** A player can't lay a card onto *anyone's* table meld
  (including their own) until they've put down at least one meld of their own.
  `Rummy::Player#melded?` (set by `#mark_melded!` inside `Game#meld`) tracks this per player
  and `Game#layoff` checks it. This was previously unenforced — a real bug, not a deliberate
  omission — until this rule was added.
- **Going out**: emptying your hand on discard ends the hand. The player who went out is
  the winner — their leftover pips are always the lowest (zero) — so `game_over?`/`winner`
  reuse the same "does any hand empty?" one-liner Go Fish/Crazy Eights already use. No
  separate pip-count scoring display exists; the "rummy" double-score bonus is deliberately
  out of scope.
- **Can't discard the card you just took from the discard pile.** `Game#draw` records it
  in `taken_from_discard`; `Game#discard` no-ops if the requested card matches (cleared on
  any deck draw, or once a discard actually goes through). Deliberately **does not** apply
  to a deck draw — putting back a card you blindly drew from the stock is normal Rummy play;
  only the discard pile is a deliberate, visible pick, so only that one is restricted.
- A game is **one hand** — no play-to-target across multiple hands.

## `deal!` deals a real per-player-count hand

`Rummy::Game#deal!` deals every player the same number of cards off the (real, shuffled)
deck, sized by player count (2p → 10, 3–4p → 7, 5–6p → 6), then flips one card from the
deck onto the discard pile — the same `number_of_cards`-by-threshold pattern Go Fish/Crazy
Eights use, just with three tiers instead of two (`TWO_PLAYER_DEAL_COUNT`/
`SMALL_GAME_DEAL_COUNT`/`BIG_GAME_DEAL_COUNT`). It previously dealt a hardcoded 8-card
`DEMO_HAND` to the current player and only 5 real cards to opponents — a scaffolding
leftover from before turn logic existed, and a real bug (uneven, wrong-sized hands). Fixed;
`spec/models/rummy/game_spec.rb`'s `#deal!` examples now assert every player gets the same
hand size, pinned per player count. **The table starts with zero melds** — `deal!` used to
also seed demo melds; that was a bug (real Rummy never starts with melds already on the
table) and has been removed.

## Implementation notes (`app/models/rummy/`)

- `Rummy::Game` holds `players`, `deck`, `current_player_index`, `round_results`, `melds`,
  `discard_pile`, `drawn_this_turn`, `taken_from_discard`.
- `RummyGame#play_turn(params)` dispatches on `params[:move]` (`draw`/`meld`/`layoff`/
  `discard`/`sort`/`smart_sort`) to the matching `Rummy::Game` method. Cards travel over
  the wire as `"<rank> <suit>"` tokens, parsed with the shared `Card.objectify` (same trick
  Crazy Eights already uses for `params[:rank]`).
- `Rummy::Meld.valid_set?`/`.valid_run?` encode aces-low ordering with a Rummy-local
  `RANK_ORDER` constant (`A` first) — deliberately not touched on the shared `Card` class,
  since the other two games don't need a reordered rank scale.
- Invalid moves **raise `Rummy::InvalidMove`** (its own file, `app/models/rummy/invalid_move.rb`,
  so Zeitwerk autoloads it independent of `game.rb`) with a player-facing message, *before* any
  mutation, so nothing half-applies. `meld`/`layoff`/`discard` each carry their own message
  (bad shape, "meld before laying off", "can't discard the card you just took", …).
  `GamesController#play` rescues it and redirects with `alert: e.message`. This is the **one
  exception** to the app's old "never surface turn-validation errors" precedent — Go Fish and
  Crazy Eights still silently no-op. The rescue is Rummy-specific but doesn't branch on game
  *type* (the other games simply never raise it). See "Surfacing invalid moves" below.
- `Rummy::Game#cards_from_hand` `reject(&:blank?)`s incoming tokens before parsing them:
  Rails renders an empty hidden value alongside every *unchecked* box in a collection of
  checkboxes, and blindly `Card.objectify`-ing that blank string raises `InvalidRank`.

## Hand sorting: `sort` vs. `smart_sort`

The hand panel has two buttons, each a `play_turn` move like any other and available
regardless of whose turn it is (sorting your own hand isn't a turn action):

- **`sort`** → `Rummy::Player#sort_hand!`: plain suit-then-rank ordering, using the everyday
  (aces-high) `Card::SUITS`/`Card::RANKS`.
- **`smart_sort`** → `Rummy::Player#smart_sort_hand!` → `Rummy::HandSorter`: groups
  sets/runs "in the making" (2+ cards, below the real 3-card meld minimum) to the left,
  suit/rank-sorting whatever's left over after.

`HandSorter` computes sets (by rank) *before* runs, and runs only ever look at the cards
sets didn't claim. That's a deliberate tie-break, not a semantic ordering — a card that
could belong to either a set or a run always ends up in the set, and that's the *only*
reason sets tend to appear before runs in the output. Which group actually sorts first is
decided by `group_key` (descending size, then the suit/rank of the group's own leading
card) — there's no explicit "sets outrank runs" rule, so it's easy to misread the output
and assume there is one.

Run detection reorders each suit's cards using `Rummy::Meld::RANK_ORDER` (aces-low) — the
same ordering real meld validity uses — so "a run in the making" means something a player
could actually eventually meld. That's a different rank order than the aces-high
`Card::RANKS` used for the plain `sort` move and for sorting each group's own cards
internally; don't assume `HandSorter` only touches one rank scale.

## Card selection UI (`rummy_turn` Stimulus controller)

Clicking a hand card toggles `.is-selected`
(`app/javascript/controllers/rummy_turn_controller.js`); the controller re-syncs the
current selection into whichever hidden fields need it on every click — the meld form's
dynamically-created `card_ids[]` inputs, the discard form's `card_id`, and each table
meld's own lay-off `card_id`. Each per-meld lay-off form needed its **own unique HTML
element ids** (`layoff_card_id_#{meld_index}`) — with N melds all using the same simple_form
field name, the generated ids collided and Capybara silently interacted with the wrong
form. The feed drawer's own toggle (`feed_drawer_controller.js`) is a two-line controller
that just flips `body.feed-open`; it's Rummy-only — the other two games keep an inline feed.
Both controllers also set a parallel `data-selected`/`data-feed-open` attribute alongside the
class they toggle, so specs assert behavior through that attribute rather than a styling class
(see `docs/testing.md`).

**`turn-actions.css`'s `.btn:disabled:first-of-type` selector was a per-button trap, not a
per-group one.** `Draw deck`/`Take discard`/`Meld selected`/`Discard selected` each live alone
inside their own `<form>` (from `button_to`/`simple_form_for`), so every one of them is
trivially "first of its type" within that form — the selector fired independently on whichever
button happened to be disabled, instead of once between the draw-pair and the meld/discard-pair
as intended. Symptom: buttons visibly drifted apart as they toggled disabled state (e.g. once
you'd drawn, `Take discard` gained its own top margin and split from `Draw deck`). Fixed by
keying the gap off DOM position (`form:nth-of-type(3)`) instead of `:disabled` state.

### Prompting the "you've drawn, now pick a card" step

The mid-turn gap — you've drawn, but the next thing to do (click a hand card) has no button
of its own — is signalled two ways, both keyed off state that was already in the DOM, with
**no new JS**:

- The hand panel header reads `Your Hand — pick a card` instead of `Your Hand` whenever
  `turn_action_disabled` is false (it's your turn *and* you've drawn).
- Hand cards pulse a green glow: `.hand:not(:has(.is-selected)) .playing-card--selectable`
  in `playing-card.css`. `playing-card--selectable` is only rendered in that same post-draw
  state, so it already *is* the state test; `:has()` kills the pulse once anything is selected.

Three deliberate constraints, since this is the app's **only** animation (see AGENTS.md
"Conventions"):

- **Glow, not border.** `.is-selected` already owns the solid `--op-color-primary-base`
  border + ring; a green border for "please pick me" would collide with "picked". The
  keyframe rebuilds the color from the `--op-color-primary-h/s/l` parts so it tracks the theme.
- **Three iterations, not infinite.** WCAG 2.2.2 wants a pause control for anything blinking
  past ~5s; 1.4s × 3 stays under it.
- **Wrapped in `prefers-reduced-motion: no-preference`** — which is why the header copy
  exists: it's the non-motion half of the same signal, and the only half a screen reader gets.

Because it's a CSS animation on freshly-rendered nodes, it **re-arms on every Turbo
re-render** of the hand (so a mid-turn sort re-triggers it) and again if you deselect your
last card. Both are arguably correct — you're back in "nothing picked yet" — but they're
emergent, not designed.

Nothing here is spec'd: it's pure CSS keyed off existing classes, and covering it would mean
asserting on a styling class, which this repo deliberately avoids (see `docs/testing.md`).

## Surfacing invalid moves (the flash toast)

The `Rummy::InvalidMove` message reaches the player through a **shared flash partial**,
`app/views/shared/_flash.html.slim`, rendered by **both** the `application` and `modal`
layouts (the four per-page auth flash divs were removed and consolidated here). It renders
each flash as an Optics `.alert.alert--flash` toast — `alert--danger` for `:alert`,
`alert--notice` for `:notice` — auto-dismissing after 4s via `flash_controller.js` (adds
`alert--leaving`, then removes the element on `transitionend`).

**Trap: Optics `.alert` is `display:none` by default *in this app*** — `optics-overrides/alert.css`
hides it and only `alert--active` (an app-local class, not a real Optics modifier, originally
for the offline banner) flips it to `display:flex`. So any alert/flash you render **must**
include `alert--active` or it stays invisible. The auto-dismiss fade also depends on the
`transition: opacity` on `.alert` staying put — remove the transition and `transitionend`
never fires, so the toast fades to invisible but is never removed from the DOM.

## Game feed (round results)

`Rummy::RoundResult` logs a feed entry for a **discard** (`card_discarded`, plus a styled
`going_out` game-response line when that discard empties the hand) and for taking the
**discard pile's top card** (`card_taken`) — but deliberately **not** for drawing from the
deck. Deck draws are hidden information (nobody else can see the card); discard draws are
visible/strategic, same as in physical Rummy, so only those two actions log. The drawer
itself (`aside.feed-drawer` in the partial) mirrors Go Fish/Crazy Eights' `.panel__content >
.feed-content` structure so it gets the same padding, and reuses their `role`-based
`.action-responses`/`.response-group` rendering for the going-out line.

**`Rummy::Game#active_card` (`discard_pile.last`) can be `nil`** — `deal!` seeds the
discard pile with exactly one card, so the very first "Take discard" empties it until the
next discard refills it. The partial guards this with a `.pile__empty` placeholder instead
of calling `.to_pathname` on `nil`; any other spot that renders `active_card` needs the same
guard.

## Fixed: `meld`/`layoff`/`discard` used to delete duplicate-valued cards

`current_player.hand.delete(card)` deletes **every** element `==` to `card`, not just one.
Back when `deal!` seeded a fixed `DEMO_HAND` without excluding those cards from the (still
full 52-card) deck, a drawn card could coincidentally duplicate one already in hand — and
melding/laying off/discarding one of them silently deleted both, corrupting the hand. This
was the actual cause of the "when the user goes out" `:js` system-spec flakiness once
attributed to a redirect/DB-write race. Fixed by removing a single instance via
`hand.delete_at(hand.index(card))` (`Rummy::Game#remove_from_hand`); regression coverage in
`spec/models/rummy/game_spec.rb`'s `#meld` examples. The real per-player `deal!` (above)
makes the specific duplicate-draw scenario moot going forward, but the underlying
delete-by-equality bug was real and would resurface with any future path that puts
duplicate-valued cards in a hand and deck at once — don't reintroduce plain `.delete(card)`
on the hand array.

A distinct, still-real symptom — Playwright raising on a hand-card click ("element is not
attached to the DOM") because a Turbo re-render swapped the card DOM out mid-click — is
mitigated in `RummyTurnHelper#select_hand_card`/`#select_only_hand_card` by retrying the
click a few times rather than adding another wait.
