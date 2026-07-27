# Architecture & Model Relationships

This project is a teaching exercise, so the architecture is chosen to demonstrate specific
concepts (Active Record, STI, serialization, Hotwire). The two-layer design below is
intentional — **new games should follow the same pattern.**

## The two layers

### 1. Active Record layer (the database)

| Model            | Role |
|------------------|------|
| `User`           | An account. Has many `sessions`, `players`, and `games` (through players). Hand-rolled auth via `has_secure_password`. |
| `Session`        | A logged-in session; looked up from a signed cookie. Accessed globally via `Current.session`. |
| `Game`           | STI base model. Columns include `type`, `name`, `game_state` (jsonb), and lifecycle timestamps (`started_at`, `ended_at`, `archived_at`). |
| `GoFishGame`     | STI subclass of `Game`. |
| `CrazyEightsGame`| STI subclass of `Game`. |
| `Player`         | **Join table** between `User` and `Game`. Also tracks `winner`. |

Key mental model: **the AR `Player` is only the user↔game join.** It carries no game-play
logic.

### 2. Domain layer (plain Ruby objects, no database)

Under `app/models/go_fish/` and `app/models/crazy_eights/`:

- `Game` — holds `players`, `deck`, `current_player_index`, `round_results` (and, for
  Crazy Eights, `william`). Contains all the rules and turn logic.
- `Player` — a **plain Ruby** player, keyed by `user.id`. Holds that player's hand (and,
  for Go Fish, `books`). Never touches the database.
- `RoundResult` — a record of what happened on a turn, used to narrate the feed.
- Go Fish only: `Book` — a completed four-of-a-kind.
- Crazy Eights only: `William` — **the discard pile** (see below).

Don't confuse the two `Player`s: `Player` (AR) is persistence/join; `GoFish::Player` and
`CrazyEights::Player` are per-game responsibilities held in memory and serialized.

`Card` and `Deck` are shared primitives at the top level (`app/models/card.rb`,
`app/models/deck.rb`), not per-game — both games reuse the same 52-card deck and shuffle.
Bare `Card`/`Deck` references inside `module GoFish` / `module CrazyEights` resolve to
these via Ruby's constant lookup.

## How the layers connect: serialization

Each STI subclass serializes its plain-Ruby game object into the `game_state` jsonb column
using a custom coder:

```ruby
class GoFishGame < Game
  serialize :game_state, coder: GoFish::Game
end
```

For this to work, each domain `Game` implements the coder contract itself:

- `self.dump(obj)` → `obj.as_json` (object → Hash for storage)
- `self.load(json)` → rebuilds the object graph (`from_json`), returning `nil` when blank
- `as_json` / `from_json` — walk the whole object graph (players, deck, books,
  round_results, william) so each sub-object round-trips.

Every domain sub-object therefore defines its own `as_json` and `self.load`. **Adding a
field to a game means updating serialization in each of those places** — miss one and it
silently drops on reload.

### Consequence: game history is a blob

Because the entire game lives in one jsonb column, there are **no normalized tables for
moves, hands, or history** — replay and the round-by-round feed are reconstructed from the
serialized `round_results` inside `game_state`.

## Lifecycle & real-time

- **Start/play**: `GamesController#start` builds the domain game and calls `deal!`;
  `#play` delegates to the STI subclass's `play_turn`, then `save!`s (which re-serializes
  `game_state`).
- **Turbo Streams**: `Game` broadcasts on commit (`after_create_commit` /
  `after_update_commit`) to update the lobby list and refresh in-progress games live.
- **Status** is derived from timestamps: no `started_at` → *Waiting*; started, not ended →
  *In progress*; `ended_at` present → *Finished*.
- **Archiving**: `ArchiveGameJob` marks any non-archived game whose `updated_at` is 2+ days
  old as `archived_at`, on a GoodJob schedule.

## Routes note

The routes file grew through the apprenticeship's learning phases and is intentionally left
somewhat inconsistent (e.g. `users/show` as a plain GET path, repeated single-action
`member` blocks). Treat existing routes as history, not as the house style to copy.

## CSS / asset pipeline

Component styles under `app/assets/stylesheets/components/*.css` need **no manifest wiring**.
`stylesheet_link_tag :app` (in `app/views/application/_head.html.slim`) is Propshaft's
convention for auto-linking every file under `app/assets/stylesheets` — drop a new file in
`components/` and it's picked up automatically. `application.scss` is an empty legacy
manifest, and `webpack.config.js` is a **dead** toolchain: `bin/dev` only runs esbuild
(`yarn build`, JS only, via `Procfile.dev`), so the PostCSS/SCSS compilation `webpack.config.js`
implies never actually runs. Ignore both when adding CSS.
