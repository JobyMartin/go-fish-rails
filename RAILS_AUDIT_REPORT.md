# Rails Audit Report — Game Platform

_Based on thoughtbot Ruby Science / Testing Rails best practices. Metrics (SimpleCov/RubyCritic) were skipped; coverage below is estimated from reading `spec/`._

**Scope:** full audit of `app/`, `spec/`, `config/`, `db/`, `lib/`.

**Context:** This is a teaching codebase. Several findings below are deliberate teaching patterns (STI + serialization, PORO domain objects); those are noted and left alone. The findings prioritize things that are genuinely broken, insecure, or duplicated — not stylistic drift the project has already accepted.

---

## Summary by severity

| Severity | Count | Headline items |
|----------|-------|----------------|
| Critical | 0 | — |
| High | 3 | Missing authorization on game actions; game-over lifecycle never persisted; duplicated feed-rendering view logic |
| Medium | 6 | `save!`-in-conditional dead branch; `ArchiveGameJob` loop; duplicated `Card`/`Deck`; duplicated Game domain helpers; 5-ivar `show`; missing controller specs |
| Low | 4 | request spec vs convention; `timer_controller` busy poll; dead `create_stacked_deck`; non-RESTful routes |

---

## Testing

### [Medium] No controller/request coverage for the game flow; authorization and error paths untested
`spec/system/games_spec.rb` covers happy-path play, but there are **no request/controller specs** for `GamesController` or `PlayersController`. The branches most likely to break — a non-participant hitting `show`/`play`, `save` failure paths, `game_over?` redirect — have no direct coverage. (Model/domain coverage is strong: every `GoFish::*` and `CrazyEights::*` PORO has a spec, plus the shared `"a persisted card game"` example.)
- Files: `spec/system/games_spec.rb`, `app/controllers/games_controller.rb`, `app/controllers/players_controller.rb`

### [Low] A request spec exists against project convention
`spec/requests/users_spec.rb` is present, though AGENTS.md says request specs are "almost never used" and behavior should be covered by system + model specs.
- Files: `spec/requests/users_spec.rb`

---

## Security

### [High] No authorization on game actions — any authenticated user can view/start/play any game
`GamesController#show`, `#start`, `#play`, and `PlayersController#create` only require authentication, never membership. There is no check that `Current.session.user` is a `Player` in the game.
- **Play/start:** any signed-in user can `POST` `play`/`start` against any game id.
- **View crash:** `show` does `@current_player = @implementation.find_player(Current.session.user.id)`; for a non-participant `find_player` returns `nil`, and the partial then calls `current_player.hand` → `NoMethodError`. So the missing check is also a latent 500.
- Files: `app/controllers/games_controller.rb:25-52`, `app/controllers/players_controller.rb:3-12`, `app/views/go_fish_games/_go_fish_game.html.slim:78-101`, `app/views/crazy_eights_games/_crazy_eights_game.html.slim:61-72`

### [Low] `passwords#update` permits params without `require`
`@user.update(params.permit(:password, :password_confirmation))` works but skips the `require(:user)` wrapper used elsewhere; a stray top-level param shape would pass silently.
- Files: `app/controllers/passwords_controller.rb:21`

_Positives:_ strong params are used correctly in `games`/`users`; `has_secure_password`, signed httponly session cookie, `rate_limit` on login and password reset, and unique index on `email_address` are all in place.

---

## Models & Database

### [High] Game-over lifecycle is never persisted — "Finished" status and win stats are dead
- `Game#end` (`app/models/game.rb:36-38`) sets `ended_at` but **is never called** anywhere in the app (grep confirms only the definition). So `Game#status` never returns `FINISHED_MESSAGE`.
- The `players.winner` boolean column is **never assigned** in app code (only the in-memory domain `GoFish::Game#winner` computes a winner, and only for the `winner` screen). So `StatsController#winner_count` (`it.winner`) is always 0 → win percentage is always `0%` for everyone.
- Files: `app/models/game.rb:23-38`, `app/controllers/stats_controller.rb:13-19`, `db/schema.rb:133` (`players.winner`)

### [Medium] `ArchiveGameJob` iterates + saves in Ruby with a silent `save`
`Game.all.where(archived_at: nil).each { ... game.save }` loads every unarchived game, mutates in Ruby, and calls unbanged `save` (failures are swallowed). The redundant `.all` before `.where` is also noise. This is expressible as one set-based update.
```ruby
Game.where(archived_at: nil).where(updated_at: ..2.days.ago).update_all(archived_at: Time.current)
```
- Files: `app/jobs/archive_game_job.rb:10-19`

---

## Controllers

### [Medium] `if @game.save!` — dead `else` branch
`GamesController#create` guards on `save!`, which **raises** on invalid records rather than returning `false`, so the `render :new` else branch is unreachable. Use `save` (no bang) if you want the re-render, or drop the conditional.
- Files: `app/controllers/games_controller.rb:18-22`

### [Medium] `show` sets five instance variables
`@game, @started, @implementation, @current_player, @opponents` — violates the project's own "one instance variable per controller action" convention (AGENTS.md). The current-player/opponents derivation belongs on the domain object or a presenter.
- Files: `app/controllers/games_controller.rb:25-32`

### [Low] Non-RESTful, duplicated route blocks
`resources :games` has three separate `member do` blocks plus a duplicate top-level `get "games/history"`. (AGENTS.md already flags routes as inconsistent — listed for completeness, low priority.)
- Files: `config/routes.rb`

---

## Code Design & Architecture

### [Medium] `Card` is byte-for-byte duplicated; `Deck` nearly so
`GoFish::Card` and `CrazyEights::Card` are identical except `CrazyEights::Card.objectify`. `GoFish::Deck` and `CrazyEights::Deck` differ only in shuffle strategy. This is the "extract a shared `Card`/`Deck`" stretch item already noted in `docs/improvement-plan.md`.
- Files: `app/models/go_fish/card.rb`, `app/models/crazy_eights/card.rb`, `app/models/go_fish/deck.rb`, `app/models/crazy_eights/deck.rb`

### [Medium] Duplicated turn/deal helpers across the two domain `Game` classes
`switch_players`/`switch_turns` (identical logic), `number_of_cards`, `deal!`, `find_player`, and `current_player` are copy-pasted between `GoFish::Game` and `CrazyEights::Game`.
- Files: `app/models/go_fish/game.rb:42-54,143-149`, `app/models/crazy_eights/game.rb:44-56,89-99`

---

## Views & Presenters

### [High] Feed-rendering logic is duplicated across both game partials (PHPitis)
The `result.for_other_players.count == 3 / == 2 / == 1` branching — ~22 lines of markup that indexes `for_other_players[0..2]` — is **duplicated verbatim** in both `_go_fish_game.html.slim` and `_crazy_eights_game.html.slim`. It's both a DRY violation and view logic that belongs in a partial or a `RoundResult` presenter.
- Files: `app/views/go_fish_games/_go_fish_game.html.slim:50-74`, `app/views/crazy_eights_games/_crazy_eights_game.html.slim:32-56`, `app/models/go_fish/round_result.rb:26`, `app/models/crazy_eights/round_result.rb:11`

### [Medium] Game partials derive `current_player`/`opponents` inline
Each partial recomputes `find_player(Current.session.user.id)` and does `players - [current_player]` in-template, and (per the authz finding) crashes for non-participants. Pushing this into the controller/presenter would remove the coupling and the duplication with `GamesController#show`.
- Files: `app/views/go_fish_games/_go_fish_game.html.slim:2-4`, `app/views/crazy_eights_games/_crazy_eights_game.html.slim:2-4`

---

## JavaScript

### [Low] `timer_controller.js#connect` busy-polls with a no-delay `setInterval`
`setInterval(() => { if (this.timer == null) this.startTimer() })` (no interval arg) schedules a tight loop just to kick off the countdown once. `connect()` can call `startTimer()` directly.
- Files: `app/javascript/controllers/timer_controller.js:7-11`

_Positives:_ `timer_controller` correctly clears its interval in `disconnect()`; `auto_play_controller` is minimal and single-purpose.

---

## Dead / commented code (Low)

- `Deck#create_stacked_deck` in both decks is test-only scaffolding left in production code; commented-out `@cards = []` / `RANKS = %w( J Q K A )` lines linger in `card.rb`/`deck.rb`.
- Files: `app/models/*/deck.rb`, `app/models/*/card.rb`

---

## Deliberate teaching patterns (intentional — not findings)

- STI (`Game` + `GoFishGame`/`CrazyEightsGame`) with a single `game_state` jsonb blob and custom serializer coder — core teaching goal.
- Plain-Ruby domain objects keyed by `user.id` that never touch the DB.
- Hand-rolled sessions via `has_secure_password` + `Current.session`.
