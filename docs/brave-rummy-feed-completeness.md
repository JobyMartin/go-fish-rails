# BRAVE Breakdown: Narrate melds, lay-offs, and every way to go out in the Rummy feed

**Status:** not started — next card up.
**Estimate:** 4 points (Small, ~4h; ~4.6h with review/pairing buffer)

## Brainstorm

### The presenting problem

The Rummy Game Feed narrates only two of the four turn actions. `Rummy::Game` appends a
`RoundResult` in exactly two places:

- `draw` — only when `source == "discard"` (`game.rb:89`)
- `discard` — always, carrying `going_out` (`game.rb:120-122`)

`meld` (`game.rb:94`) and `layoff` (`game.rb:103`) mutate `melds` and the player's hand and
return. Nothing is appended. So a player watching the feed sees a take, then a discard, with
no record of the run laid down in between.

### The real problem, found while breaking this down

`going_out` is welded to the discard path — computed in one place, `game.rb:121`, as
`current_player.hand.empty?` after removal. **Under Bicycle rules three different actions can
empty a hand:** melding out, laying off your last card, and discarding your last card. Two of
those three currently produce no "went out and won!" line at all.

This is worse than cosmetic because of the controller quirk already documented in AGENTS.md:
`GamesController#play` checks `game_over?` *before* playing the turn, so the move that wins
redirects to the game board, not the winner screen. For a meld-out, **the feed is the only
surface that would announce the win** — and it is silent.

So the card is not "add two line types." It is "make the feed narrate all three
hand-emptying actions, and add meld/lay-off lines."

### What is NOT broken (checked, not assumed)

- `game_over?` is `players.any? { it.hand.empty? }` and `winner` is
  `players.find { it.hand.empty? }` (`game.rb:68-73`). Both read the hand directly, not
  `going_out`, so **a meld-out is correctly detected as a win.** There is no stall.
- `meld` not calling `switch_turns` is correct in both directions: if the player went out the
  game is over, and if they did not they still owe a discard.

### Decisions made

| Question | Decision |
| --- | --- |
| Name the cards in feed lines? | **Yes** — matches the existing voice (`took a 9 of Diamonds`). |
| Privacy of drawn cards? | **Non-issue.** Every card named is already public: melded and laid-off cards are face-up on the table, discards are face-up, and a card taken from the discard pile was face-up. Deck draws produce no `RoundResult` at all, so the privacy line is already correct and this card does not move it. |
| Lay-off says which meld? | **No** — `"Alice laid off 8 of Hearts"`. Naming the target meld means giving `Meld` an owner and threading it through `as_json`/`load`. Deferred (see Follow-ups). |
| Meld + lay-off in one turn? | **Separate feed entries**, one `RoundResult` per action, like `draw`/`discard` today. |
| Invalid moves in the feed? | **No.** They stay with the acting player as flash toasts. The feed is the public record of what happened; a rejected move did not happen. |

### Target feed output

```
Alice took a 7 of Hearts from the discard pile
Alice melded 5 of Hearts, 6 of Hearts, 7 of Hearts
Alice laid off 8 of Hearts
Alice discarded a K of Spades
```

...with `Alice went out and won!` appended to whichever action emptied her hand.

## Approach

### Chosen: a `move` discriminator on `Rummy::RoundResult`

```ruby
attr_reader :move, :current_player, :cards, :going_out

def initialize(move:, current_player:, cards: [], going_out: false)
  @move = move.to_sym
  ...

def for_other_players
  lines = [ action_line ]
  lines << "#{current_player.name} went out and won!" if going_out
  lines
end
```

`action_line` dispatches on `move` over `:took` / `:melded` / `:laid_off` / `:discarded`.

**Why the discriminator over adding `cards_melded` + `card_laid_off` fields:** the existing
three fields are already mutually exclusive — a result is *either* a take *or* a discard — but
that invariant is encoded only by convention, and every reader has to know it. Adding two more
fields makes five where at most one is ever set. `move` names the thing the branch is actually
on. The usual cost of this shape change is backfilling `game_state` blobs; **there are no
persisted games worth preserving**, so that cost is zero here.

### Blast radius: Rummy only

`GoFish::RoundResult` is a separate class with its own shape (`go_fish_game_spec.rb:17` is
untouched), and the shared `RoundFeed` needs **no changes**.

| File | Change |
| --- | --- |
| `app/models/rummy/round_result.rb` | the real work — new shape, `action_line` dispatch, `.load` |
| `app/models/rummy/game.rb` | 3 call sites edited, 2 added (`meld`, `layoff`) |
| `spec/models/rummy/round_result_spec.rb` | ~13 examples, all constructor calls rewritten |
| `spec/models/rummy/game_spec.rb` | `:150` `.card_taken` and `:289` `.card_discarded` → `.cards.first`; `:295`/`:303` `going_out` unchanged |
| `spec/system/games_spec.rb` | `:320` same rename, plus new meld/lay-off/meld-out coverage |
| `app/views/rummy_games/_rummy_game.html.slim` | **nothing** |

### What we get for free

- **Going-out styling is preserved.** Appending the win line last keeps the result at two
  lines, so `RoundFeed` still tags it `[:action, :game_response]`. The existing role
  assertions and the `feed-game-response` system spec (`games_spec.rb:530`) pass unchanged.
- **`RoundFeed` is untouched** — roles fall out of line count, which `round_feed_spec.rb`
  already covers generically.

### Why this is one card, not two

The instinct to fix the end-of-game hole first is right about *priority*, but the halves are
welded:

1. **You cannot emit a going-out line from `meld` without the discriminator.** With today's
   shape a meld result has neither `card_taken` nor `card_discarded`, so `for_other_players`
   falls into its else branch and builds `"Alice discarded a "` — an empty interpolation —
   then appends the win line.
2. **Skipping the meld text costs the win line its styling.** `RoundFeed` assigns roles
   positionally. With no action line in front of it, the win line is the only line and comes
   back `[:action]`, rendering as a plain player-action instead of a styled game response.
3. Once the discriminator exists and `meld` emits a result anyway, the meld text is **one line**
   in the case statement.

**Resolution: one card, sequenced internally so the going-out path is driven first.** Write the
meld-out system spec first and let it force the discriminator into existence; the meld/lay-off
text falls out as a byproduct.

### Mid-way checkpoint

After the meld-out system spec goes green, the discriminator and all three `going_out` call
sites are done — that is the correctness half. Everything after it is text and spec cleanup.

## Value

**The going-out fix is the value; the meld/lay-off narration is the packaging.** A player who
melds out is redirected to the game board with a silent feed — nobody at the table is told the
game ended. That is a correctness gap at the game's most important moment. The meld/lay-off
lines are real but comfort-level.

This also argues against shipping a partial: meld/lay-off lines *without* the going-out fix
delivers the comfort and leaves the correctness gap.

**Optimize for quality, specifically:** the `going_out`-on-every-action path deserves careful
coverage (all three hand-emptying routes, each asserted). The meld/lay-off wording is a place
to pick a phrasing and move on.

## Estimate

**4 points — Small, ~4 hours.** ~4.6h with the 15% review/pairing buffer, which is what keeps
it off 2 points. No new files, no view change, no migration, no CSS, no JS. The code is small
and every pattern exists; the time is ~13 rewritten specs plus ~8 new ones under the
≤7-line-per-`it` rule.

Solo is fine. Worth a second pair of eyes on the `.load` round-trip only.

### Risks

| Risk | Likelihood | Severity | Notes |
| --- | --- | --- | --- |
| `move` round-trips as a String | High | Low | No explicit `as_json`; `game.rb:38` leans on ActiveSupport serializing ivars, so `:melded` returns as `"melded"`. The `move.to_sym` in `initialize` absorbs it — but dispatch anywhere without it silently no-matches and yields a blank line. **Add a `.load` spec asserting the symbol.** |
| `game_spec.rb:390` may be a vacuous assertion | Medium | Low | `loaded.round_results == game.round_results` with no `==` on `RoundResult` only passes today if the array is empty. If it still passes after the reshape, that is **not** proof the round-trip works. Verify early. |
| Controller quirk complicates the meld-out spec | Medium | Low | `game_over?` is checked before `play_turn`, so the win redirects to the game board. That page renders the feed, so this likely makes the spec *easier* than the winner screen — confirm early rather than assume. |
| 4-branch `case` hits the ≤7-line method rule | High | Trivial | `action_line` lands right at 7 lines. Fine, but no room to grow. |

### Incremental shipping

Effectively atomic — see "Why this is one card." The only real increment is meld-out first and
lay-off-out second, but the second is ~2 lines once the first works.

### Dependencies and sequencing

Nothing blocks this. It brushes the deferred audit finding that game-over is never persisted
(`Game#end` has no caller, `players.winner` never written) — this card makes the feed the de
facto win report, which *raises* rather than lowers the case for eventually persisting it.

## Implementation Plan

- [ ] System spec first: a player melds their last cards; feed shows the meld line **and** a
      styled `feed-game-response` win line. Watch it fail.
- [ ] Reshape `Rummy::RoundResult` — `move`/`cards`/`going_out`, `action_line` dispatch,
      `for_other_players` appending the win line.
- [ ] Update `.load` for `move` (assert Symbol) and `cards` (array via `Card.load`).
- [ ] Add `going_out: current_player.hand.empty?` to the `meld` and `layoff` results.
- [ ] Add the meld and lay-off `round_results <<` call sites; convert `draw`/`discard` to `move:`.
- [ ] Rewrite `round_result_spec.rb` constructor calls; add per-move describe blocks following
      the existing text-plus-roles shape.
- [ ] Update `game_spec.rb:150`/`:289` and `games_spec.rb:320` to `.cards.first`; verify `:390`
      is not vacuous.
- [ ] Add system coverage for the lay-off line and lay-off-out.
- [ ] Confirm the `count: 1` feed tripwires (`games_spec.rb:170`, `:303`) still hold — neither
      path melds, so they should.
- [ ] `bundle exec rspec` + `bin/rubocop`.
- [ ] Update `docs/games/rummy.md` with the feed's move vocabulary and the three going-out routes.

## Follow-ups (deliberately out of scope)

- **Deck draws are unnarrated.** The feed says nothing when a player draws from the deck, so
  you read a meld and a discard with no hint of a draw. A card-less "Alice drew from the deck"
  line would close it. Separate concern from the meld gap.
- **Lay-off does not say which meld.** Wants an owner/id on `Meld` plus serialization —
  `"Alice laid off 8 of Hearts onto Bob's run"`.
- **Game-over is still never persisted** — the standing audit finding.
