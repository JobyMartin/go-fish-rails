# Feature: Extract the round feed into a `RoundFeed` presenter

## Feature summary

Both game partials (`_go_fish_game.html.slim`, `_crazy_eights_game.html.slim`) render the
game feed by branching on `result.for_other_players.count` (`== 3 / == 2 / == 1`) and
styling each indexed line differently. That count-branching is duplicated verbatim across
the two templates.

Lift the branching into a namespace-neutral presenter, `RoundFeed` (+ a `FeedLine` value
object with `text` and `role`), at `app/models/round_feed.rb`. Each `RoundResult` delegates
via `feed_lines`. The partials then iterate `result.feed_lines`, rendering one styled slot
per line based on `role`.

The positioning rule the presenter owns:
- **first line** → `action`
- **last line** → `game_response`
- **a middle line** (only ever at 3 lines) → `player_response`
- a single line is just `action` (first and last collapse to `action`)

**Pure refactor.** No on-screen behavior changes. The `count == 3` path is currently dead
(no game emits 3 lines today) but is **preserved** so rendered output is provably identical.

## Test coverage

### `spec/models/round_feed_spec.rb` (new file)

#### `#lines`
- [x] one line → a single `FeedLine` with role `action`
- [x] two lines → roles `action`, `game_response`
- [x] three lines → roles `action`, `player_response`, `game_response` (preserved dead path)
- [x] zero lines → empty
- [x] each `FeedLine` carries the original text at its position

### Views (regression via system spec, no new view spec)

- [x] `_go_fish_game.html.slim` iterates `result.feed_lines` instead of count-branching
- [x] `_crazy_eights_game.html.slim` iterates `result.feed_lines` the same way

## Related specs (regression check)

- `spec/system/games_spec.rb` — the feeds must render identically before and after
- `spec/models/go_fish/round_result_spec.rb` — `for_other_players` unchanged; add `feed_lines`? (delegation is thin — covered by presenter spec + system spec)
- `spec/models/crazy_eights/round_result_spec.rb` — same

## Notes

- `role` values: `action | player_response | game_response`.
- Presenter takes a plain array (no card/deck/rule knowledge) — a presentation seam, not a
  domain seam, so it doesn't preempt Card 2.
- Slim markup per role is copied verbatim from the existing branches (icons, BEM classes).
