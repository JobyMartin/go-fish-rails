# Leaderboard

A page at `/leaderboard` ranking every user by wins. Built during the
performance-focused week, so **how** it's written matters as much as what it does.

## The performance exercise

The page was written deliberately unoptimized — `User.all.sort_by { -it.games_won }` with
a query per row from each of `User#games_played` / `#games_won` / `#time_played` — so the
week could measure it, optimize it, and measure again. **Those four `User` methods are gone**;
`LeaderboardEntry` replaced them, and it is the only place the stats are computed now.

**Complete: 3,014 queries / 4,115 ms -> 2 queries / 36 ms** (3 / 22 ms once paginated — see
"Pagination with Kaminari"). Phase 1 was eager loading,
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
and the board itself — the page is one query. (Pagination later added a third; see
"Pagination with Kaminari".)

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
duration sum, and (as of `_v02.sql`) `win_percentage` including its ranked floor. Ruby holds
only the *presentation*: `.ranked` for ordering and `win_percentage_for` in
`LeaderboardHelper`, which renders `UNRANKED` (`—`) when the column is `NULL`.

`win_percentage` is a `CASE WHEN COUNT(players.id) >= 5` in SQL, so **the SQL literal is the
floor** — a view can't read a Ruby constant. `MINIMUM_RANKED_GAMES` was deleted along with the
Ruby method: once nothing but the specs read it, a Ruby constant is a *second*, unenforced copy
of the number, and a spec deriving its expectation from it would pass while the view disagreed.
The specs name `5` literally instead. Changing the floor means a new `_v03.sql` plus a
migration, and updating those specs.

Two casts matter in that expression: `::numeric` before the division (integer division would
floor every percentage to 0 or 100, and `double precision` would round halves to even instead
of matching Ruby's `Float#round`), then `::integer` on the result so the attribute arrives as
an `Integer` rather than a `BigDecimal` that would interpolate as `"50.0%"`.

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

## Sorting with Ransack

Four columns sort: **Player**, **Games played**, **Wins**, **Time played**. Numeric ones use
`default_order: :desc` so the first click shows most-wins-first. The sort rides in the URL
(`?q[s]=games_played+desc`), so a sorted board is shareable.

`LeaderboardController#index` stays one instance variable — `@search =
LeaderboardEntry.ranked_search(params[:q])` — and the view iterates `@search.result`. The
default-sort logic sits on the model, not the controller.

**Ransack authorizes nothing by default (v4+).** `ransackable_attributes` is mandatory; without
it `sort_link` silently does nothing. **Never allowlist via `column_names`** — Ransack exposes
predicates like `q[password_digest_start]=$2a$`, which lets an attacker binary-search a password
hash one character at a time. On this view it would also expose nothing useful; on `User` or
`games.game_state` it would leak credentials and every player's hand.

**`win_percentage` is still not sortable — but that is now a choice, not a limit.** It was a
Ruby method (Ransack only sorts real columns); since `_v02.sql` it is a real column and could
be added to `ransackable_attributes`. It is left off because sorting on it needs a decision
about where the `NULL` unranked rows belong. `Game#status` is the genuinely unsortable case
(derived from `started_at`/`ended_at`), which is why Ransack fits this view — every displayed
column is real SQL — better than it fits the games lobby.

**A refused sort still leaves a `Sort` node behind.** It resolves to no column and emits no
`ORDER BY`, so `search.sorts.empty?` is false while the board is *unordered* — `?q[s]=id desc`
rendered rows in arbitrary order. Hence `ranked_search` falls back on
`unless search.sorts.any?(&:attr_name)`, not on `if empty?`. Also note `search.sorts =`
**appends** rather than replaces, so the dud node survives harmlessly; specs assert on
`filter_map(&:attr_name)` rather than `map(&:name)` for that reason.

**The Rank column is positional, not a real rank.** It counts rows in the current result set, so
sorting by Time played still shows the longest-playing user as "Rank 1". See "Card: a real rank
column" — that card should land *before* Ransack filtering, which is what makes the positional
number actively misleading.

## Pagination with Kaminari (2026-07-28)

25 rows a page, via [Kaminari](https://github.com/kaminari/kaminari). Measured against the same
`perf:seed[1000,5000]` dataset as everything above:

| | Queries | Median |
|---|---|---|
| Phase 3, unpaginated | 2 | 36 ms |
| **Paginated, page 1** | **3** | **22 ms** |
| Paginated, page 40 (last) | 3 | 24 ms |

**One more query, and still ~40% faster.** Kaminari adds a `COUNT(*)` for `total_pages`; that
costs less than hydrating 979 Active Record objects the page never displays. Same lesson as
Phase 2 from the other side — SQL was never the bottleneck, object hydration was.

**The last page costs the same as the first**, which will not stay true forever. Deep `OFFSET`
makes Postgres walk and discard the skipped rows, but the view aggregates to ~1,000 rows, so
`OFFSET 975` discards under a thousand. Do not read this table as "offset pagination is fine";
read it as "offset pagination is fine at a thousand rows."

**Per-page lives in `config/initializers/kaminari_config.rb`,** app-wide (`default_per_page = 25`,
`max_per_page = 100`), not in `paginates_per` on the model — `/games` is next in line and will
want the same default. Note `max_per_page` does nothing yet: it only caps a user-supplied `per`,
and nothing passes `params[:per]` into `.per`. It is there for the page that eventually does.

**The controller still sets exactly one instance variable.** Pagination went into
`LeaderboardHelper#paged_entries`, not the controller, because the view needs *both* the
`Ransack::Search` (for `sort_link`) and the paginated relation — a second ivar would break the
one-ivar-per-action convention. "Which page am I on" is presentation, same as `win_percentage_for`.
`entries` must be a **local** in the template: calling `paged_entries` twice (rows, then
`paginate`) would build a second relation and re-issue the SELECT.

**Rank is `entries.offset_value + index + 1`** (`rank_for`), so page 3 starts at 51 instead of
restarting at 1. `offset_value` is the relation's `OFFSET`, i.e. `(page - 1) * per_page`. An
out-of-range `?page=999` has `offset_value` 24950 but zero rows, so no bogus rank renders.

### The Kaminari templates are ours now

`app/views/kaminari/*.html.slim` overrides the gem's partials, because Kaminari ships
`.page.current` / `.prev` / `.next` / `.gap` and this project uses **BEM**. They are now
`pagination__page` (+ `--current`), `pagination__step`, and `pagination__gap`, styled by
`app/assets/stylesheets/components/pagination.css`.

- **`.pagination` is Optics'**, not ours — Optics defines it as a flex row (with `__divider` and a
  rows-per-page `.form-group`), and Kaminari's `<nav>` already carries that class, so the container
  comes free and our elements extend the design system's block. The risk if Optics later ships its
  own `pagination__page`: a collision.
- **`rails g kaminari:views default -e slim` crashes on Rails 8.1** — it calls
  `ActiveSupport::Deprecation.warn` as a class method, which Rails no longer allows. Copy the
  `.slim` partials out of `$(bundle info kaminari-core --path)/app/views/kaminari/` by hand.
- **The gem's `.slim` partials have drifted from its `.erb` ones.** The Slim copies are missing
  `role="navigation" aria-label="pager"` and the `unless current_page.out_of_range?` guard that
  suppresses `Next` on `?page=999`. Both were restored by hand.
- **`Last »` was deliberately removed** — `last_page_tag` is gone from `_paginator`, and
  `_last_page.html.slim` deleted with it rather than left as a partial nothing renders. First
  stays, as a bare `«`.
- **The link labels are i18n, not template strings.** Kaminari reads
  `t('views.pagination.first')` etc. from its *own* locale file; `config/locales/en.yml` overrides
  `views.pagination.first` to `&laquo;` because app locales load ahead of gem ones. That is the
  place to change a label — the partials stay generic. The `aria-label="First page"` on that link
  is **not** decoration: with the word gone, the link's entire accessible name would be `«`, which
  a screen reader announces as "left double angle quotation mark." Icon-only visually, named for
  assistive tech. (It is hardcoded in the partial while the visible label lives in the locale file;
  if this app ever gets translated, those two need to move together.)
- **Converted the gem's `==` to `=`.** In Slim `==` prints raw and `=` prints escaped, but under
  Rails `=` respects `html_safe`, so both render identically here — the gem uses `==` only because
  Slim outside Rails escapes regardless. This repo uses `==` nowhere else. That makes the
  `.html_safe` calls on the labels **load-bearing**: they are what keeps `&laquo;` / `&hellip;`
  from rendering as visible entities. Don't tidy them away.
- **Spacing tokens are one step smaller than they look.** This app overrides
  `--op-space-scale-unit` to `2rem` against Optics' `1rem`, so every token is 2× its Optics value —
  `--op-space-medium` would have been a 3.2rem gap.

## Card: a real rank column (`RANK()` in `_v03.sql`)

Replace the positional `rank_for` with a window function in the view:

```sql
RANK() OVER (ORDER BY games_won DESC) AS rank
```

**Do this before adding Ransack filtering.** Sorting alone only preserves the existing flaw;
filtering breaks the number's *meaning*. `rank_for` counts rows in the result set, so with
`?q[games_won_gteq]=10` position 1 becomes "best of the matches" rather than rank 1 on the board —
and nothing on the page signals that it changed. A view-computed rank is immune: the view computes
it before a request's `WHERE` or `ORDER BY` touches it, so it survives sorting, filtering, and
pagination, and `rank_for` / `offset_value` both disappear.

**Filtering on a window-function column works, which is not obvious.** A window function is
illegal in a `WHERE` at its own query level, but a view is a separate level and Postgres will not
push the predicate down through it — `LeaderboardEntry.where("rank <= 10")` is fine. Verified
against the seeded data.

Then `rank` is allowlistable in `ransackable_attributes` like any real column, which buys
`?q[rank_lteq]=10` as a "top 10" filter. Safe to expose — an integer aggregate on a view with no
sensitive columns. Still by hand; the `column_names` warning above stands.

**Open decisions:**

- **`RANK()` vs `DENSE_RANK()`.** `RANK()` ties then skips (8, 8, 10); `DENSE_RANK()` ties without
  skipping (8, 8, 9). Boards conventionally want `RANK()`.
- **Where the zero-game users go.** They all tie at the bottom on one rank, and `RANK()` leaves a
  large gap after them. This is the same unresolved question that keeps `win_percentage` out of
  `ransackable_attributes`.
- **Cost is small but unindexable.** 1 ms for 5 runs at 1,004 rows, but `RANK()` sorts every row
  on every request and no index removes that. It scales with user count, not query count.

## Next: the games index is unbounded

`/games` is **not** an N+1 — Bullet reports nothing on it, and `_game-card` walks no
associations. It is a different failure: `@games = Game.all` with no limit. At 5,020 seeded
games, measured with `perf:measure`:

| | |
|---|---|
| Queries | 4 (16 ms of SQL) |
| Views | 537–606 ms |
| GC | 60–85 ms |
| Cards rendered | 5,020 |

**~95% of the request is rendering `game-card` 5,020 times** — each one a partial lookup, a
`dom_id`, and a `button_to` that builds a CSRF-tokened form. Eager loading cannot help; there
is nothing to preload. The fixes are bounding the query (pagination — **Kaminari is already
installed and configured app-wide**, so this is `.page(params[:page])` plus a `paginate` call
away, and `app/views/kaminari/` means the BEM markup and styling come with it) or scoping it,
since `Game.all` includes archived and long-finished games that are not joinable at all.

**Pagination will collide with the Turbo broadcast.** `Game#broadcast_game_update` does
`broadcast_append_later_to('games', target: 'all-games-list')`, so a new game appends a card to
whatever page the user is looking at — wrong once the list is paginated and sorted newest-first.
Decide that before adding page links, not after.

## Bullet is off by default in development

`Bullet.enable = ENV["BULLET"].present?` in `config/environments/development.rb`, so
`bin/dev` runs without it and `BULLET=1 bin/dev` turns it on.

**Bullet's overhead tracks association bookkeeping, not query count and not object count.**
Holding this page at a constant 4 queries and growing the dataset:

| Users | Players | Bullet OFF | Bullet ON |
|---|---|---|---|
| 100 | 1,515 | 74 ms | 867 ms |
| 200 | 2,989 | 153 ms | 2,556 ms |
| 400 | 5,981 | 217 ms | 9,574 ms |

The same series *before* the `.size` fix, at 108 queries, was 1,012 / 2,928 / 10,353 ms —
essentially identical. **Cutting queries by 96% moved Bullet's cost ~8%.** At 1,000 users it
turns a ~0.55s page into ~72s, and the slow query it reports is its own overhead.

Object count is not the driver either, though it looks like it from this page alone: `/games`
loads 5,466 objects and pays only **+7%** with Bullet on. The difference is that the
leaderboard reaches its objects *through* `includes(:players, :games)`, giving Bullet ~21,000
object→association pairs to register and re-examine, while `/games` loads flat collections
whose card partial walks no associations at all. **Preloading is what makes Bullet expensive.**

This is why `perf:measure` disables Bullet: with it on, every number in this doc would have
been a Bullet benchmark. Turning it off in dev is safe because the test suite runs
`Bullet.raise` — verified by reintroducing an N+1 and watching the spec fail.

## What it ranks and why

Four columns: games played, wins, win %, time played.

- **Win % has a floor** of 5 games, in the view's `CASE WHEN` — below it the view selects
  `NULL` and the page renders `LeaderboardEntry::UNRANKED` (`—`).
  `UNRANKED` moved off `User` with the stat methods. Without a floor, one lucky
  win reads as 100% and outranks a 400-of-600 record.
- **Time played is wall-clock, not attention.** `SUM(ended_at - started_at)` over the
  user's finished games. Nothing tracks per-turn timing, so a game where someone walked
  away for an hour charges that hour to every player in it. Deriving it from
  `archived_at` instead was rejected: `ArchiveGameJob` retires games after 2 idle days,
  so every abandoned game would contribute a full 48 hours and swamp the ranking.
- **Games with no `ended_at` contribute nothing** to win % or time played, so abandoned
  games are invisible here.

**Ties no longer rank arbitrarily.** `LeaderboardEntry.ranked` orders by wins desc, then *fewer*
games played, then username — so equal-wins users resolve to the tighter record and identical
requests return an identical board.

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
