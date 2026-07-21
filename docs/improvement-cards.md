# Improvement Cards

Three scoped improvements (~1–2h each) drawn from the `rails-audit` report (`RAILS_AUDIT_REPORT.md`) and the `improve-codebase-architecture` review. Ordered lowest-risk first; each is independent.

---

## Card 1 — Extract the round feed into a `RoundResult` presenter — ✅ Done

**Done:** `RoundFeed` (+ `FeedLine`) at `app/models/round_feed.rb`; each `RoundResult#feed_lines`
delegates to it; both partials iterate `result.feed_lines`, styling by `role`. Pure refactor —
`spec/models/round_feed_spec.rb` pins the first/last/middle rule at lengths 0–3; the dead
`count == 3` path is preserved. Committed `3aec445`.

**Goal**
The `for_other_players.count == 3 / == 2 / == 1` feed-rendering logic exists in exactly one place. Both game partials iterate a single presenter interface (e.g. `result.feed_lines`) instead of branching on count. No behavior change on screen; the block is no longer duplicated.

**Why**
Both assessments flagged this. The audit rated it **High (Views)**: ~22 lines of markup that index `for_other_players[0..2]` are duplicated *verbatim* across the two partials — PHPitis plus a DRY violation. The architecture review made it the "Strong / feed presenter" candidate: the feed-shape decision has no *locality* (it lives in the templates), so it's testable only through a rendered page. Deepening it to one interface gives locality, leverage across both games, and a plain-object test surface.

**Files & code referenced**
- `app/views/go_fish_games/_go_fish_game.html.slim:50–74` — the `for_other_players.count` branching
- `app/views/crazy_eights_games/_crazy_eights_game.html.slim:32–56` — the duplicated copy
- `app/models/go_fish/round_result.rb:26` — `for_other_players`
- `app/models/crazy_eights/round_result.rb:11` — `for_other_players`
- New spec alongside the existing `spec/models/*/round_result_spec.rb`

**Note (from BRAVE breakdown — `docs/brave-card-1-round-feed-presenter.md`):** the
`count == 3` branch is **currently dead** — Go Fish emits at most 2 lines (the "asked"
and "took" lines share one `unless went_fishing || made_a_catch` guard) and Crazy Eights
at most 2. Decision: **preserve** the 3-line path anyway to keep this a pure, provably
behavior-preserving refactor. Planned shape: a namespace-neutral `RoundFeed` presenter
(+ `FeedLine` value object) at `app/models/round_feed.rb`, with each `RoundResult`
delegating via `feed_lines`.

---

## Card 2 — Collapse the duplicated `Card` / `Deck` into one shared module

**Goal**
There is one `Card` implementation and one `Deck` implementation. `GoFish` and `CrazyEights` reuse them; the games' only difference (shuffle strategy) is passed in, not forked into a whole second copy. Both games' specs stay green, and each STI subclass keeps its explicit serializer.

**Why**
The audit rated this **Medium (Code Design)** and the architecture review listed it as "Worth exploring / collapse the two Card/Deck modules." `GoFish::Card` and `CrazyEights::Card` are **byte-for-byte identical** except for `CrazyEights::Card.objectify`; `GoFish::Deck` and `CrazyEights::Deck` differ only in shuffle order. These are two shallow modules kept in sync by hand — the documented stretch item in `docs/improvement-plan.md`. One deep `Card`/`Deck` passes the deletion test (removing a copy concentrates complexity) and lets a third game reuse the module.

**Files & code referenced**
- `app/models/go_fish/card.rb` and `app/models/crazy_eights/card.rb` — identical but for `objectify`
- `app/models/go_fish/deck.rb` and `app/models/crazy_eights/deck.rb` — differ only in shuffle strategy (per-suit vs whole-deck)
- Callers of `Card`/`Deck` in `app/models/*/game.rb`, `app/models/*/player.rb`
- Existing coverage to keep green: `spec/models/*/card_spec.rb`, `spec/models/*/deck_spec.rb`
- Note from `docs/improvement-plan.md` (stretch item) — sequence this last, since a shared module touches every domain spec
- Cleanup opportunity while here: the test-only `Deck#create_stacked_deck` and commented-out lines in `card.rb`/`deck.rb`

**Note (from BRAVE breakdown — `docs/brave-card-2-shared-card-deck.md`):** the two `Card` classes
are byte-for-byte identical but for `objectify` (used once, in `crazy_eights_game.rb:8`, and generic
enough to share); the two `Deck`s differ only in shuffle, and **neither `deck_spec` pins that
difference** — the Go Fish per-suit shuffle is very likely an artifact. Decision: **flat top-level
`::Card`/`::Deck`** (bare refs in the game namespaces resolve for free) and **Approach A** — collapse
the fork to one whole-deck shuffle rather than passing a strategy in; fall back to "pass the shuffle
in" only if the full suite goes red. `create_stacked_deck` is dead (zero callers) — remove it.
Sized X-Small (~under 2h).

---

## Card 3 — Authorize game actions to participants

**Goal**
Only a `Player` in a game can view (`show`), start, play, or the relevant join path — a non-participant is redirected (to the lobby with a flash) rather than reaching game state. In particular, viewing a game you're not part of no longer raises a `NoMethodError`.

**Why**
The audit rated this **High (Security)**. `GamesController#show/start/play` and `PlayersController#create` require authentication but never membership, so any signed-in user can `POST play`/`start` against any game id. It's also a latent 500: `show` does `find_player(Current.session.user.id)` → `nil` for a non-participant, and the partial then calls `current_player.hand` → `NoMethodError`. So the missing check is both an authorization gap and a crash.

**Files & code referenced**
- `app/controllers/games_controller.rb:25–52` — `show`, `start`, `play` (no membership check)
- `app/controllers/players_controller.rb:3–12` — `create` (join)
- `app/views/go_fish_games/_go_fish_game.html.slim:78–101` and `app/views/crazy_eights_games/_crazy_eights_game.html.slim:61–72` — where `current_player` is dereferenced and would crash
- New coverage: a controller/request or system spec for the non-participant path (currently only happy-path system specs exist in `spec/system/games_spec.rb`)
- Open decision for implementation: redirect-with-flash vs 404 for a non-participant

---

_Not selected this round (still in the reports for later): persist the game-over lifecycle via a `Game#record_turn` deep module — the architecture review's top recommendation and the audit's other High finding (revives "Finished" status and win stats). See `RAILS_AUDIT_REPORT.md` and the architecture HTML report._
