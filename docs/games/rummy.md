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
- **Going out**: emptying your hand on discard ends the hand. The player who went out is
  the winner — their leftover pips are always the lowest (zero) — so `game_over?`/`winner`
  reuse the same "does any hand empty?" one-liner Go Fish/Crazy Eights already use. No
  separate pip-count scoring display exists; the "rummy" double-score bonus and "can't
  discard the card you just drew from discard" are deliberately out of scope.
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
  `discard_pile`, `drawn_this_turn`.
- `RummyGame#play_turn(params)` dispatches on `params[:move]` (`draw`/`meld`/`layoff`/
  `discard`) to the matching `Rummy::Game` method. Cards travel over the wire as
  `"<rank> <suit>"` tokens, parsed with the shared `Card.objectify` (same trick Crazy
  Eights already uses for `params[:rank]`).
- `Rummy::Meld.valid_set?`/`.valid_run?` encode aces-low ordering with a Rummy-local
  `RANK_ORDER` constant (`A` first) — deliberately not touched on the shared `Card` class,
  since the other two games don't need a reordered rank scale.
- Invalid meld/lay-off attempts (wrong shape, or a card not actually in the current
  player's hand) **silently no-op** — this matches the app's existing precedent of not
  surfacing turn-validation errors anywhere (no other game does either).
- `Rummy::Game#cards_from_hand` `reject(&:blank?)`s incoming tokens before parsing them:
  Rails renders an empty hidden value alongside every *unchecked* box in a collection of
  checkboxes, and blindly `Card.objectify`-ing that blank string raises `InvalidRank`.

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
