# Leaderboard

A page at `/leaderboard` ranking every user by wins. Built during the
performance-focused week, so **how** it's written matters as much as what it does.

## The performance exercise

The page was written deliberately unoptimized — `User.all.sort_by { -it.games_won }` with
a query per row from each of `User#games_played` / `#games_won` / `#time_played` — so the
week could measure it, optimize it, and measure again.

**The baseline has been taken and Phase 1 has landed** (below). The remaining work is
indexes, and collapsing the whole thing into one `GROUP BY`. There are still **no indexes**
on `players.winner` or `games.type`, so that comparison is still available.

Two tools support this, both in `lib/`:

| | |
|---|---|
| `bin/rails "perf:seed[users,games]"` | bulk data; clears first so re-runs are identical |
| `bin/rails "perf:measure[path,runs]"` | query count + median timing over real requests |
| `bin/rails perf:clear` | drop the seeded rows |

`perf:measure` signs in as a seeded user and issues real requests through
`ActionDispatch::Integration::Session`, so **view-level** queries are counted too — most of
this page's N+1 lived in `LeaderboardHelper`, which a model-only benchmark would miss.
Prefix with `BULLET=1` to measure with Bullet active.

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

## Phase 1: eager loading (2026-07-27)

| | Queries | Median |
|---|---|---|
| Baseline | 3,014 | 4,115 ms |
| `includes(:players, :games)` | 1,008 | 1,767 ms |
| `games_played` `.count` → `.size` | **4** | **580 ms** |

Two changes, and the second is the one worth remembering.

**`.count` always issues `SELECT COUNT(*)`, even on a preloaded association.** `.size`
counts the loaded array and only queries when the association is not loaded. So `includes`
did its job and `games_played` threw the result away 1,004 times. That is why Bullet
reported this one as *Need Counter Cache* rather than *USE eager loading* — it knew eager
loading alone could not help. `.size` gets the counter cache's benefit with no migration,
which is why Phase 3 was dropped.

**The two changes only work as a pair.** `includes` without `.size` leaves 1,004 queries;
`.size` without `includes` leaves just as many.

**Both associations must be named.** `games` is `has_many through: :players`, but
preloading `:players` does not preload it, and `includes(players: :game)` does not either —
`user.games` and `user.players.map(&:game)` are different associations to Rails even though
they return the same rows. Measured: `:players` alone → 1,006 queries; `players: :game` →
1,007; `:players, :games` → 3. Preload the association name the code actually calls.

## Bullet is off by default in development

`Bullet.enable = ENV["BULLET"].present?` in `config/environments/development.rb`, so
`bin/dev` runs without it and `BULLET=1 bin/dev` turns it on.

**Bullet's overhead is superlinear in loaded objects, not in queries.** Holding the page at
a constant 4 queries and growing the dataset:

| Users | Players | Bullet OFF | Bullet ON |
|---|---|---|---|
| 100 | 1,515 | 74 ms | 867 ms |
| 200 | 2,989 | 153 ms | 2,556 ms |
| 400 | 5,981 | 217 ms | 9,574 ms |

The same series *before* the `.size` fix, at 108 queries, was 1,012 / 2,928 / 10,353 ms —
essentially identical. Cutting queries by 96% moved Bullet's cost ~8%, because it registers
every loaded object to decide what to warn about, and `includes` loads all 15,036 players
either way. At 1,000 users this makes a ~0.55s page take ~72s, and the slow query Bullet
reports is its own overhead.

This is why `perf:measure` disables Bullet: with it on, every number in this doc would have
been a Bullet benchmark. Turning it off in dev is safe because the test suite runs
`Bullet.raise` — verified by reintroducing an N+1 and watching the spec fail.

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
