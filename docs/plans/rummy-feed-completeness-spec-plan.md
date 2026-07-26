# Feature: Narrate melds, lay-offs, and every way to go out in the Rummy feed

## Feature summary

The Rummy Game Feed is the public record of a turn. Today it narrates only two of the four
actions — taking from the discard pile, and discarding — so a player who melds or lays off
sees nothing in the feed between their take and their discard.

Worse, `going_out` is computed only on the discard path, but **three actions can empty a
hand**: melding out, laying off your last card, and discarding your last card. Combined with
`GamesController#play` checking `game_over?` *before* playing the turn (the winning move
redirects to the game board, not the winner screen), **the feed is the only surface that would
announce a meld-out win — and it is silent.**

After this card, a player watching the feed sees:

```
Alice took a 7 of Hearts from the discard pile
Alice melded 5 of Hearts, 6 of Hearts, 7 of Hearts
Alice laid off 8 of Hearts
Alice discarded a K of Spades
```

...with `Alice went out and won!` appended to whichever action emptied her hand, styled as a
`feed-game-response`.

Constraints, decided in the BRAVE breakdown:

- Cards are named in every line (matches the existing `took a 9 of Diamonds` voice). No privacy
  concern: every card named is already face-up. Deck draws still produce no feed entry.
- Lay-off does **not** say which meld it went onto.
- Meld and lay-off each get their own feed entry — one `RoundResult` per action.
- Invalid moves stay as flash toasts and never reach the feed.
- `Rummy::RoundResult` gains a `move` discriminator (`:took` / `:melded` / `:laid_off` /
  `:discarded`) plus `cards` and `going_out`, replacing the mutually-exclusive
  `card_taken` / `card_discarded` pair. Rummy only — `GoFish::RoundResult` and `RoundFeed` are
  untouched.

**Sequencing:** the meld-out system spec is written first. It cannot pass without the
discriminator, so it drags the correctness half (going-out on all three routes) into existence;
the meld/lay-off wording falls out as a byproduct.

## Test coverage

### `spec/system/games_spec.rb` (modify existing)

#### when the user melds out (new context — hand is exactly one valid run)
- [x] shows the meld line and a styled going-out message in the feed
- [x] ends the game without a discard

#### when the user lays off their last card (new context — a run on the table, one matching card in hand)
- [x] shows the lay-off line and a styled going-out message in the feed

#### when the user takes a full turn (existing context, add examples)
- [x] shows the meld line in the feed naming all three cards
- [x] shows the lay-off line in the feed naming the card

#### existing examples to update
- [x] `:320` `round_results.last.card_discarded` → `.cards.first`
- [x] `:170` / `:303` `count: 1` feed tripwires still hold (neither path melds)
- [x] `:530` `feed-game-response` going-out-on-discard spec passes unchanged

### `spec/models/rummy/round_result_spec.rb` (rewrite constructor calls)

#### `#feed_lines` per move
- [x] `:took` — `'Joby took a 9 of Diamonds from the discard pile'`, roles `[:action]`
- [x] `:melded` — `'Joby melded 3 of Hearts, 4 of Hearts, 5 of Hearts'`, roles `[:action]`
- [x] `:laid_off` — `'Joby laid off 8 of Hearts'`, roles `[:action]`
- [x] `:discarded` — `'Joby discarded a 7 of Spades'`, roles `[:action]`

#### `#feed_lines` when going out
- [x] appends `'Joby went out and won!'` after a discard
- [x] appends the win line after a **meld** (the hole this card closes)
- [x] appends the win line after a **lay-off**
- [x] marks the win line `:game_response` (keeps the two-line `[:action, :game_response]` shape)

#### `.load`
- [x] rebuilds `move` as a **Symbol** even though the blob stores a String
- [x] rebuilds `cards` as an array of `Card`
- [x] rebuilds `going_out`

### `spec/models/rummy/game_spec.rb` (modify existing)

#### `#meld`
- [x] records a round result naming the melded cards
- [x] marks the result as going out when the meld empties the hand
- [x] does not mark going out when cards remain

#### `#layoff`
- [x] records a round result naming the laid-off card
- [x] marks the result as going out when the lay-off empties the hand

#### `#draw` / `#discard` (existing examples to update)
- [x] `:150` `.card_taken` → `.cards.first`
- [x] `:289` `.card_discarded` → `.cards.first`
- [x] `:295` / `:303` `going_out` assertions unchanged
- [x] `does not record a round result when drawing from the deck` unchanged

#### `as_json / from_json`
- [x] **`:390` `preserves round results` is vacuous** — `round_results` is empty under
      `before { game.deal! }` and `RoundResult` has no `==`. Replace it with an assertion on a
      real result's `move`, `cards`, and `going_out` after a played turn.

## Related specs (regression check)

- `spec/models/round_feed_spec.rb` — role assignment is positional and generic; expected to pass
  untouched, but run it to confirm the two-line shape assumption.
- `spec/models/go_fish/round_result_spec.rb`, `spec/models/go_fish_game_spec.rb` — separate class,
  must stay green.
- `spec/models/rummy_game_spec.rb` — STI subclass + serialization round-trip.
- `app/views/rummy_games/_rummy_game.html.slim` — **no change expected**; it iterates
  `result.feed_lines`.
