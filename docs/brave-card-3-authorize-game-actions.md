# BRAVE Breakdown: Card 3 — Authorize game actions to participants

## Brainstorm

`GamesController#show/start/play/winner` currently require authentication but never check
**membership**, so any signed-in user can `POST play`/`start` against any game id and read any
game's state. It's also a latent 500: `show` calls `find_player(...)` → `nil` for a
non-participant, and the partial then dereferences `current_player.hand` → `NoMethodError`. So
the missing check is simultaneously an authorization gap and a crash.

**Scope decisions resolved during the breakdown:**

- **Protect `show`, `start`, `play`, and `winner`.** `winner` isn't in the card's list, but it
  leaks game state to a non-participant the same way `show` does; folding it into a scoped
  `before_action` costs one extra symbol in the `only:` list, so it's in.
- **Leave `join` (`PlayersController#create`) alone.** Joining is inherently a non-participant
  action, so a membership check doesn't apply. The card's "or the relevant join path" wording is
  out of scope for this card.
- **Non-participant → redirect to the lobby with a flash** (not a 404). Matches the card's goal
  line and the real-world scenario (a user following a stale link), and is the friendlier UX for
  a legitimate-but-lost user.

**Real-world scenario:** a signed-in user clicks a stale/shared link to a game they're not part
of. Instead of a 500 (or silently reaching another game's state), they're bounced to the lobby
with "You're not in that game."

## Approach

Follow the existing auth pattern rather than inventing one. `app/controllers/concerns/authentication.rb`
already runs `before_action :require_authentication`; the natural parallel is a pair of scoped
before_actions in `GamesController`:

- **`set_game`** — `@game = Game.find(params[:id])`, scoped `only: %i[show start play winner]`.
  The four actions drop their own `Game.find`, removing the duplicated lookup.
- **`require_participation`** — runs *after* `set_game`, same `only:` scope. Checks
  `@game.users.include?(Current.session.user)` (cheap — `Game has_many :users, through: :players`)
  and, if false, `redirect_to games_path, alert: "You're not in that game."`

**Ordering is the thing to get right:** `set_game` → `require_participation` → action body. The
500 fix depends on `require_participation` short-circuiting *before* `show` renders the partial
that calls `current_player.hand`. "One instance variable per action" still holds — `@game` set in
a filter is idiomatic Rails.

**Reuse:** existing `Authentication` concern shape, existing `has_many :users, through: :players`
association. No new UI components; the flash uses whatever the layout already renders.

**Mid-way check:** after wiring `set_game` + `require_participation`, the existing happy-path
system specs in `spec/system/games_spec.rb` should stay green (participants still get in). Then the
new non-participant spec should go red → green as the filter lands.

**Error/recovery state:** the flash *is* the recovery affordance — it tells the user why they
were bounced and leaves them in the lobby to pick a game they're actually in.

## Value

- **Business:** closes the audit's **High (Security)** finding — no signed-in user can act on or
  read a game they're not in.
- **User:** a lost user gets a clear redirect + message instead of a 500 error page. Two-for-one:
  security fix *and* stability fix (the latent `NoMethodError` on `show` goes away).
- **Priority:** essential, not nice-to-have — it's a live authorization hole plus a crash.
- **Optimize for:** **quality with a hint of speed.** The code is trivial; the quality lives in
  covering the non-participant path. Don't gold-plate, but don't skip the tests that are the
  whole point of the card.

## Estimate

- **Size: Small (4 points, ~half a day)**, with a 15% review/pairing buffer → ~4.5h effort. Could
  land at X-Small (2 pts) since the code is ~10 lines and the pattern already exists; sized up to
  Small because "quality" means covering the non-participant path across multiple actions and
  refactoring four action bodies carries a small tail.
- **Test structure:** system specs, matching the suite and project convention (request specs are
  almost never used here). The non-participant case is the inverse of the existing setup — a
  `game` whose only `Player` belongs to a *different* user, then assert the signed-in `user` is
  redirected to the lobby with the flash and never sees game content.
- **Top risks (all low):**
  1. **before_action ordering** — `set_game` before `require_participation` before the body;
     this is what makes the 500 fix work. *Likelihood low, severity medium* → pin with a test.
  2. **Refactoring four actions to drop their own `find`** — small chance of a miss; guarded by
     existing happy-path system specs. *Likelihood low, severity low.*
  3. **Test-shape choice** (system vs request) — resolved to system. *Negligible.*
- **Incremental shipping:** small enough to do in **one pass** (not carved into show-first /
  rest-later). All-or-nothing at this size.

## Implementation Plan

- [ ] Write a failing system spec: a non-participant visiting `game_path(other_game)` is
      redirected to `games_path` with the flash and sees no game content.
- [ ] Add a matching spec (or specs) for the `POST` actions — a non-participant hitting
      `start`/`play` is redirected and does not mutate the game.
- [ ] Add `before_action :set_game, only: %i[show start play winner]` and move `@game = Game.find(params[:id])` out of those four action bodies.
- [ ] Add `before_action :require_participation, only: %i[show start play winner]` running after
      `set_game`; redirect to lobby with `alert:` when `@game.users` excludes the current user.
- [ ] Confirm ordering: `set_game` → `require_participation` → action; verify the non-participant
      `show` no longer reaches `current_player.hand`.
- [ ] Run the full suite — new specs green, existing happy-path system specs still green.
- [ ] Run `bin/rubocop`.
