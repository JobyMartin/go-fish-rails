# Go Fish

The in-app rules page (`app/views/pages/rules.html.slim`) is the player-facing source of
truth. This doc summarizes the rules and points at how they map to code.

## Rules

- **Object:** win the most **books**. A book is four of a kind (e.g. four Kings).
- **Rank:** cards rank Ace (high) to 2 (low); suits don't matter for matching.
- **The deal:** dealt per-player based on the number of players (see deal counts below).
- **A turn:** ask an opponent for a rank you already hold.
  - If they have cards of that rank, they hand them over and **your turn continues**.
  - If they don't, you **Go Fish** (draw from the deck); your turn ends unless the drawn
    card happens to be the rank you asked for.
  - If your hand is empty you draw from the deck; if the deck is also empty your turn is
    skipped.
- **Books:** completing four of a rank forms a book. When all 13 books are made the game
  ends.
- **Win:** most books wins; tie broken by the highest-ranked book.

## Implementation notes (`app/models/go_fish/`)

- `GoFish::Game` holds `players`, `deck`, `current_player_index`, `round_results`.
- **Deal counts** (`GoFish::Game`): fewer than `BIG_GAME_PLAYER_COUNT` (4) players →
  `SMALL_GAME_DEAL_COUNT` (7 cards each); 4+ players → `BIG_GAME_DEAL_COUNT` (5 cards each).
- **Hand size matters for turn flow.** The `GoFishGame#play_turn` wrapper checks
  `current_player.hand_size` first: an empty hand triggers `fish_and_skip` (draw and skip)
  instead of a normal inquiry. Turn continuation vs. ending is decided in
  `handle_cards_and_end_turn` / `end_turn` based on whether a catch was made.
- `GoFish::Player` holds `hand` and `books`; `make_book_if_possible(rank)` promotes four of
  a rank into a `Book`.
- `GoFish::RoundResult` produces the narration shown in the feed (`for_current_player` vs.
  `for_other_players`).
- Winner logic lives in `Game#winner` (`handle_winner` / `handle_tie`, the latter comparing
  `highest_book_value`).
