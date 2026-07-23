# Feature: Add Rummy to the game platform (Phase A — wire the game, demo state)

## Feature summary

Rummy becomes a real, playable-from-the-lobby game type alongside Go Fish and Crazy
Eights, following the STI "adding a game" pattern (`docs/architecture.md`,
`mockup-html/RUMMY-HANDOFF.md`). Scope for this pass, per the handoff's locked next-session
plan (steps 1–5):

- `RummyGame` is registered in `Game::PLAYABLE_TYPES` and selectable when creating a game.
- `Rummy::Game`/`Rummy::Player`/`Rummy::Meld`/`Rummy::RoundResult` exist as real domain
  objects with a full `load`/`dump`/`as_json`/`from_json` round-trip contract (same
  acceptance bar as Go Fish/Crazy Eights — `spec/support/shared_examples/persisted_card_game.rb`).
- `deal!` seeds a **fixed demo state** (a nice hand, several melds — a run and a
  four-of-a-kind — a discard top, opponents with card counts) — not real per-player
  dealing logic yet. This mirrors `rummy_preview.html.slim`'s hardcoded arrays.
- `RummyGame#play_turn(params)` is a **no-op stub** — real dispatch (draw/meld/layoff/discard)
  is explicitly out of scope for this pass (see "Phase B" below).
- The real partial `rummy_games/_rummy_game.html.slim` renders that demo state through the
  same four-panel `.game` grid as the other games, replacing the isolated
  `/pages/rummy_preview` mockup end-to-end from the lobby.
- The `/pages/rummy_preview` scaffolding route/controller/view is retired once the real
  partial works.

**Explicitly not built in this pass** (Phase B, separate spec plan if pursued): `play_turn`
dispatch on `params[:move]` (draw/meld/layoff/discard), `Rummy::Meld` set/run validation,
lay-off, going-out/scoring, winner detection. `Rummy::Game#game_over?`/`#winner` return
`false`/`nil` for now, matching the "no real logic yet" scope.

## Test coverage

### `spec/models/game_spec.rb` (modify existing)

#### `.playable_types`
- [ ] includes `'RummyGame' => 'Rummy'` alongside the existing two types

### `spec/models/rummy/player_spec.rb` (new file)

#### `#add_cards`
- [ ] appends the given cards to the player's hand

#### `.load`
- [ ] rebuilds a player with id, name, and hand from a hash

### `spec/models/rummy/meld_spec.rb` (new file)

#### `.load`
- [ ] rebuilds a meld's cards from a hash

(No set/run validation yet — that's Phase B.)

### `spec/models/rummy/round_result_spec.rb` (new file)

#### `#feed_lines`
- [ ] describes what happened in language other players see (mirrors
      `CrazyEights::RoundResult`/`GoFish::RoundResult` — one line per meaningful fact)

#### `.load`
- [ ] rebuilds a round result from a hash

### `spec/models/rummy/game_spec.rb` (new file)

#### `#deal!`
- [ ] deals every player a hand
- [ ] seeds the table with demo melds
- [ ] seeds a discard pile with a top card

#### `#find_player`
- [ ] returns the player matching the given user id

#### `#current_player`
- [ ] returns the player at `current_player_index`

#### `#game_over?`
- [ ] returns false (no real going-out logic yet)

#### `#winner`
- [ ] returns nil (no real scoring yet)

#### `#active_card`
- [ ] returns the top of the discard pile

#### `as_json` / `from_json` round-trip
- [ ] preserves players, deck, melds, discard pile, round results, and current_player_index

### `spec/models/rummy_game_spec.rb` (new file, AR-level STI class)

#### `#build_game`
- [ ] returns a `Rummy::Game` seeded with a `Rummy::Player` per user

#### `#play_turn`
- [ ] no-op stub does not raise and does not change game state

#### shared contract
- [ ] `it_behaves_like 'a persisted card game'`

### `spec/factories/rummy_games.rb` (new file)

- [ ] empty per-type factory, mirroring `spec/factories/go_fish_games.rb`

### `spec/system/games_spec.rb` (modify existing)

#### `when user creates a rummy game`
- [ ] "Rummy" appears as a selectable type in the new-game form
- [ ] starting the game renders the four-panel board (table melds, deck/discard piles,
      hand, players list) with the seeded demo state
- [ ] the game feed drawer tab is present

## Related specs (regression check)

- `spec/system/games_spec.rb` — full file, since `Game.playable_types.values` and shared
  panel-class assertions (`panel--board`/`--controls`/`--hand`/`--aside`) touch all three games
- `spec/models/go_fish_game_spec.rb`, `spec/models/crazy_eights_game_spec.rb` — confirm the
  new registry entry and any shared-example changes don't regress the existing games
- `spec/system/pages_spec.rb` (if it exists — covers `/pages/rummy_preview`) — will need
  updating/removing once that route is retired in step 4 below
