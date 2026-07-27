# Leaderboard

A page at `/leaderboard` ranking every user by wins. Built during the
performance-focused week, so **how** it's written matters as much as what it does.

## It is deliberately unoptimized

`LeaderboardController#index` is `User.all.sort_by { -it.games_won }`, and each of
`User#games_played` / `#games_won` / `#time_played` runs its own query per row. That
is a textbook N+1 that degrades linearly with user count.

**This is the exercise, not a defect.** The plan is: seed a large dataset, measure the
naive version, then optimize (one `GROUP BY`, indexes on `players.winner` and
`games.type`, possibly a counter cache) and measure again. Anyone who "fixes" the N+1
before the measurement happens destroys the before/after comparison the week exists for.

There are currently **no indexes** on `players.winner` or `games.type` — also on purpose,
for the same reason.

## Baseline (2026-07-27)

Measured with `bin/rails perf:measure` against `bin/rails "perf:seed[1000,5000]"`
(1,000 users, 5,020 games, 15,036 players — see `lib/perf_seed.rb`):

| | `GET /leaderboard` |
|---|---|
| Queries | **3,014** |
| Median | **4,115 ms** (range 3,833–4,265) |

Roughly three queries per user row, plus the request's own two.

**Compare query counts, not milliseconds.** The count was identical across all five runs;
the timing swung ~400ms. Query count is the reproducible claim — same seed, same count, any
machine. Timing is the one that makes the point to a human.

Re-run `perf:seed` before each measurement. It clears first precisely so the dataset is
reproducible; an earlier additive version quietly doubled the player table between runs,
which would have invalidated the comparison with nothing visibly wrong.

## What it ranks and why

Four columns: games played, wins, win %, time played.

- **Win % has a floor.** `User::MINIMUM_RANKED_GAMES` (5) — below it, `win_percentage`
  returns `nil` and the view renders `User::UNRANKED` (`—`). Without a floor, one lucky
  win reads as 100% and outranks a 400-of-600 record.
- **Time played is wall-clock, not attention.** `SUM(ended_at - started_at)` over the
  user's finished games. Nothing tracks per-turn timing, so a game where someone walked
  away for an hour charges that hour to every player in it. Deriving it from
  `archived_at` instead was rejected: `ArchiveGameJob` retires games after 2 idle days,
  so every abandoned game would contribute a full 48 hours and swamp the ranking.
- **Games with no `ended_at` contribute nothing** to win % or time played, so abandoned
  games are invisible here.

**Ties rank arbitrarily.** The sort key is only `-games_won`, so two users with equal wins
order by whatever `User.all` returns. Needs a tiebreaker whenever sorting gets real work.

## Ranking depends on winners being persisted

Before this page, `players.winner` was never written and `Game#end` had no caller, so
`StatsController` reported `0%` for everyone forever. `Game#finish!` now closes that:
it sets `ended_at`, marks the winning `Player`, and is called from `GamesController#play`
once `game_state.game_over?`.

Consequences worth knowing:

- **Only games finished after this landed are counted.** Every pre-existing row has a
  `nil` `ended_at`, so a freshly migrated database shows an empty-looking board.
- `Game#status` returns `Finished` for the first time, and `StatsController`'s win %
  is real rather than permanently `0%`.
- All three games' domain `winner` methods return exactly one player, so `players.winner`
  as a boolean is sound — no tie handling needed. (Go Fish's `handle_winner` compares
  `players.first` to `players.last` and is wrong for 3+ players, but that's a separate
  pre-existing bug, not a leaderboard concern.)

## Users have a `username`

Added because the board needed something human to display and `users` had only
`email_address` — printing that would publish every user's email to every signed-in user.
The migration backfills from the email local-part, de-duplicating by appending the id,
then applies `null: false` and a unique index.

Note that domain players (`GoFish::Player#name` etc.) are still never given the user's
name — they default to `'Fisher'` / `'Rummy Player'`. The leaderboard reads `User#username`
directly and doesn't touch the serialized state.
