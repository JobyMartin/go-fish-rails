  # BRAVE Breakdown: Card 1 — Extract the round feed into a `RoundResult` presenter

## Brainstorm

**The work.** Both game partials (`_go_fish_game.html.slim` and `_crazy_eights_game.html.slim`)
contain ~22 lines of near-identical Slim that branch on `result.for_other_players.count`
(`== 3 / == 2 / == 1`) to render the game feed. The card lifts that count-branching out of the
templates so each partial iterates a single presenter interface (`result.feed_lines`) instead.

**What the branching actually does.** Each element of `for_other_players` maps to a styled slot:

| Element | count == 3 | count == 2 | count == 1 |
|---|---|---|---|
| `[0]` | `feed-content__player-action` | `feed-content__player-action` | `feed-content__player-action` |
| `[1]` | `response-group__player-response` | `response-group__game-response` | — |
| `[2]` | `response-group__game-response` | — | — |

The rule: **first line = action, last line = game-response, a middle line (only at count 3) =
player-response.** That is the entire decision the presenter needs to own.

**Resolved ambiguity — the `count == 3` branch is currently dead.** Tracing both
`for_other_players` methods, Go Fish can only ever emit 0/1/2 lines (the "asked" and "took" lines
share one `unless went_fishing || made_a_catch` guard) and Crazy Eights emits at most 2. No game
produces three lines today.

**Decision:** preserve the 3-line rendering path anyway. This stays a **pure refactor** with a
clean "rendered output is identical" story for the reviewer — we do not confirm-and-drop the dead
branch in this card.

## Approach

**Follow the house pattern.** Plain Ruby objects live under `app/models/`, so the presenter lives
there too — namespace-neutral, not under `go_fish/` or `crazy_eights/`.

- **New object: `app/models/round_feed.rb`** (+ a small `FeedLine` value object with `text` and
  `role`, where `role ∈ action | player_response | game_response`). `RoundFeed` takes a
  `for_other_players` array and returns positioned `FeedLine`s using the first/last/middle rule.
- **Delegate on each `RoundResult`.** Both `GoFish::RoundResult` and `CrazyEights::RoundResult`
  get `def feed_lines; RoundFeed.new(for_other_players).lines; end`. The partials then iterate
  `result.feed_lines`, exactly as the card suggests — shape logic in one file.
- **Presentation seam, not a domain seam.** The presenter knows nothing about cards/decks/rules,
  so it does not preempt Card 2 (shared `Card`/`Deck`) or set a domain-sharing precedent.

**Why not alternatives:** `app/presenters/` would introduce a new top-level convention this app
doesn't have — too big a decision for a one-object refactor. Namespacing it under a game would
misrepresent ownership. Duplicating `feed_lines` on each class would just relocate the duplication.

**Initial spike (test-first):** write `spec/models/round_feed_spec.rb` — feed it arrays of length
1, 2, and 3 and assert the resulting `role`s. That pins the behavior (including the preserved
3-line path) before any view is touched.

**Mid-way check:** with the presenter and its spec green, convert the Go Fish partial first and
run `spec/system/games_spec.rb`. If the page still renders identically, the approach is sound;
then convert Crazy Eights.

**Error/recovery states:** none — pure refactor, no user-facing paths change.

## Value

- **Business (teaching codebase):** code health that makes the *next* feature cheaper. Both the
  audit (High / Views) and the architecture review flagged this exact duplication. A third game
  reuses the presenter instead of copy-pasting the feed markup a third time.
- **User:** none visible, by design. The win is entirely maintainability + a plain-object test
  surface (feed shape was previously testable only through a rendered page).
- **Priority:** the intended first, lowest-risk, independent card of the three.
- **Optimize for:** **learning, with a hint of speed.** First presenter object and first shared
  seam in this codebase — worth doing test-first and getting the interface clean, while staying
  brisk to leave room for other cards.

## Estimate

- **4 points (Small / ~half day) nominal; ~2 points (X-Small / ~1h) expected.** Mechanical work is
  ~1h; the Small sizing reflects the learning tax (first presenter, first seam, TDD) and proving
  no behavior changed. With the 15% review/pairing buffer, ~1h15–1h30 realistically — inside the
  2-hour window with room for another card.
- **Pairing:** light. A quick review of the interface + the "views render identically" claim.

**Top risks**

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| Behavior drift — markup no longer renders identically (esp. the preserved dead `count == 3` path) | Low | Medium | Run `spec/system/games_spec.rb` green before *and* after; unit-test presenter at lengths 1/2/3 |
| Scope creep into Card 2 (presentation seam becomes a domain seam) | Low | Low | Presenter takes a plain array; no card/deck/rule knowledge |
| HTML structure differing between the two partials | Very low | Low | Both partials already use identical markup per count — one presenter serves both |

**Incremental shipping:** ship the presenter + Go Fish partial conversion; leave the Crazy Eights
swap as a follow-up if interrupted (presenter already proven).

**Sequencing:** independent of Cards 2 & 3; no dependency to clear first. Lightly demonstrates a
clean presentation-only seam that Card 2 can learn from.

## Implementation Plan

- [x] Write `spec/models/round_feed_spec.rb` — assert `role`s for arrays of length 1, 2, and 3 (pins the preserved 3-line path)
- [x] Create `app/models/round_feed.rb` (+ `FeedLine` value object) implementing the first/last/middle rule; make the spec green
- [x] Add `feed_lines` delegating to `RoundFeed` on `GoFish::RoundResult` and `CrazyEights::RoundResult`
- [x] Replace the `count`-branching block in `_go_fish_game.html.slim` (lines ~50–74) with an iterate over `result.feed_lines`
- [x] Run `spec/system/games_spec.rb` — confirm Go Fish feed renders identically
- [x] Replace the duplicated block in `_crazy_eights_game.html.slim` (lines ~32–56) the same way
- [x] Run full `bundle exec rspec` + `bin/rubocop` green; confirm both feeds render identically
