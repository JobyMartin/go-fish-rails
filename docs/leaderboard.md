# Leaderboard

A page at `/leaderboard` ranking every user by wins. Built during the
performance-focused week, so **how** it's written matters as much as what it does.

## The performance exercise

The page was written deliberately unoptimized — `User.all.sort_by { -it.games_won }` with
a query per row from each of `User#games_played` / `#games_won` / `#time_played` — so the
week could measure it, optimize it, and measure again.

**Complete: 3,014 queries / 4,115 ms -> 2 queries / 36 ms.** Phase 1 was eager loading,
Phase 2 measured indexes and rejected them, Phase 3 replaced the whole thing with a Scenic
database view. There are still **no indexes** on `players.winner` or `games.type` --
see Phase 2 for why, and revisit them against the view's aggregation.

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
reproducible. Two bugs had to be fixed to make that true, both silent: an early additive
version doubled the player table between runs, and `insert_players` read games with `pluck`
and no `ORDER BY`, so Postgres was free to return rows in any order and pair the seeded
random draws with different games each run. Only `time_played` drifted from the second one,
so a digest covering games played and won looked stable while the data was not.

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
which is why the planned counter-cache phase was dropped entirely.

**The two changes only work as a pair.** `includes` without `.size` leaves 1,004 queries;
`.size` without `includes` leaves just as many.

**Both associations must be named.** `games` is `has_many through: :players`, but
preloading `:players` does not preload it, and `includes(players: :game)` does not either —
`user.games` and `user.players.map(&:game)` are different associations to Rails even though
they return the same rows. Measured: `:players` alone → 1,006 queries; `players: :game` →
1,007; `:players, :games` → 3. Preload the association name the code actually calls.

## Phase 2: indexes — measured and rejected (2026-07-27)

The original plan called for indexes on `players.winner` and `games.type`. **Neither was
added, and neither should be** until the aggregation moves into SQL.

**Nothing queries those columns.** After Phase 1 the page runs three queries — `SELECT *
FROM users`, `players WHERE user_id IN (...)`, `games WHERE id IN (...)`. `players.winner`
and `games.type` appear in no `WHERE` clause: `games_won` filters winners in Ruby, and the
page never filters by game type at all. An index only earns its write cost on a column the
database is asked to search, sort, or join on.

**And SQL is not the bottleneck.** Where 580 ms goes at 1,000 users:

| | Time | Share |
|---|---|---|
| Active Record hydration | 532 ms | 92% |
| Ruby stat computation | 72 ms | 12% |
| `sort_by(-games_won)` | 6 ms | 1% |
| Raw SQL (`EXPLAIN ANALYZE`, all three queries) | 2.4 ms | 0.4% |

A perfect index could win at most 2.4 ms of 580 ms. The cost is turning 21,060 rows into
21,060 Ruby objects to print four numbers per row.

`EXPLAIN` reports **Seq Scan** on all three, including `players WHERE user_id IN (...)`
where an index on `user_id` exists. That is Postgres being right: the query wants all
15,036 rows, and a full read beats an index lookup per row. Indexes find a few rows among
many; they do not help fetch all of them.

**Still open against the view.** The Phase 3 view *does* read `players.winner` in
`COUNT(*) FILTER (WHERE players.winner)`, so an index on it is finally worth benchmarking --
against that query, on a seeded dataset, before and after.

## Phase 3: a Scenic database view (2026-07-28)

| | Queries | Median |
|---|---|---|
| Baseline | 3,014 | 4,115 ms |
| Phase 1 (eager loading + `.size`) | 4 | 580 ms |
| **Phase 3 (`leaderboard_entries` view)** | **2** | **36 ms** |

**1,507× fewer queries, 114× faster.** The two remaining queries are the session lookup
and the board itself — the page is one query.

The aggregation lives in `db/views/leaderboard_entries_v01.sql`, managed by
[Scenic](https://github.com/scenic-views/scenic). `LeaderboardEntry` is an ordinary
Active Record model pointed at that view, so everything above the database is plain Ruby —
no `find_by_sql`, no SQL strings in app code:

```ruby
LeaderboardEntry.ranked                        # the whole board
LeaderboardEntry.where("games_won > 50")       # composes like any scope
LeaderboardEntry.find_by(username: "ace")      # `users.id AS id` gives it a primary key
```

**What lives where.** The view holds the aggregation — counts, the winner filter, the
duration sum. Ruby holds the *display rules*: `.ranked` for ordering and `#win_percentage`
for the `MINIMUM_RANKED_GAMES` floor. A versioned view is awkward to change (each edit is a
new `_v02.sql` plus a migration), so rules likely to be tweaked stay in Ruby.

**Why it is fast.** Phase 1 left 21,060 Active Record objects being hydrated to print four
numbers per row — 92% of the request. The view returns 1,004 already-aggregated rows, so
Postgres does the counting and Rails instantiates one object per displayed row.

**Details worth keeping:**

- `users.id AS id` gives the view a primary key, so `find` / `first` / `last` work without
  `self.primary_key =`.
- `readonly?` returns `true` — a view cannot be written through, and this turns a confusing
  database error into `ActiveRecord::ReadOnlyRecord`. Covered by a spec.
- **Both joins are `LEFT`** so a user who has never joined a game still appears with zeroes.
  An inner join would silently drop them.
- **The joins cannot inflate the counts:** each player belongs to exactly one game, so
  joining `games` adds no rows. In the other direction `COUNT(players.id)` would be wrong.
- `::double precision` on the duration sum keeps `time_played` a Float; without it Postgres
  returns numeric, which arrives as `BigDecimal` and breaks `divmod(1.hour)` in the helper.
- Scenic dumps the view into `schema.rb` as `create_view`, so `db:schema:load` still works
  and there is no need to switch to `structure.sql`.
- **Ties are no longer arbitrary.** `.ranked` orders by wins desc, then fewer games played,
  then username, so identical requests return an identical board.

**To change the view:** `rails generate scenic:view leaderboard_entries` copies
`_v01.sql` to `_v02.sql` and writes an update migration. Do not edit `_v01.sql` in place —
it is the historical record of what the migration created.

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
