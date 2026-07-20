# Crazy Eights

## Rules

- **Object:** be the first to empty your hand.
- **The deal:** dealt per-player based on the number of players (see deal counts below).
  The remaining cards form the draw deck; the top card starts the discard pile.
- **A turn:** play a card from your hand that matches the **rank or suit** of the current
  top card of the discard pile. **8s are wild** — an 8 may be played on anything, and the
  player names the suit that must be matched next.
- **If you can't play:** draw from the deck until you draw a playable card (that card is
  then played). This drawing loop is handled in `CrazyEightsGame#play_turn`.
- **Win:** the first player to run out of cards wins (`Game#game_over?` returns true when
  any player's hand is empty).

## ⚠️ William is the discard pile

`CrazyEights::William` is **not** an AI or an opponent — it is the **discard pile** (the
collection of placed cards). The name is an inside joke that the instructors approved.

- `william.active_card` → `cards.last`, i.e. the **top of the discard pile** (the card the
  next play must match).
- Playing a card does `william.cards << placed_card`.

Do not model an AI player around it; there isn't one.

## Implementation notes (`app/models/crazy_eights/`)

- `CrazyEights::Game` holds `players`, `deck`, `current_player_index`, `round_results`, and
  `william`.
- **Deal counts:** fewer than `BIG_GAME_PLAYER_COUNT` (3) players →
  `SMALL_GAME_DEAL_COUNT` (7 cards each); 3+ players → `BIG_GAME_DEAL_COUNT` (5 cards each).
- `valid_player_cards(player)` returns the cards a player may legally play (matching the
  active card's rank or suit, or any 8).
- `CrazyEights::RoundResult#for_other_players` narrates the placed card and, for a wild 8,
  the chosen suit.
- `CrazyEights::Card.objectify("K Spades")` parses a `"<rank> <suit>"` string back into a
  `Card` (used when a placed card arrives from the controller/params).
