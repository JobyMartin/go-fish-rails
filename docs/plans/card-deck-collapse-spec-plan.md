# Feature: Collapse `Card`/`Deck` into a shared primitive

## Feature summary

`GoFish::Card` and `CrazyEights::Card` are byte-for-byte identical except `CrazyEights::Card`
adds `self.objectify`. `GoFish::Deck` and `CrazyEights::Deck` differ only in shuffle strategy
(per-suit shuffle vs. whole-deck shuffle) — a difference the existing specs don't pin. This is
a pure refactor per `docs/brave-card-2-shared-card-deck.md`: one top-level `::Card`, one
top-level `::Deck`, both games reuse them, no user-visible behavior changes. `objectify` moves
onto the shared `Card`. Dead code (`create_stacked_deck`, stray comments) is deleted.

Because this is "keep green," the plan is different from a normal feature: instead of new
failing tests driving new code, existing green specs get **moved and rewritten to reference
the new top-level constants**, then re-run to confirm nothing broke. The two per-game
`card_spec.rb`/`deck_spec.rb` pairs (already byte-for-byte identical apart from CE's
`#objectify` example) merge into one shared spec each.

## Test coverage

### `spec/models/card_spec.rb` (new — merged from `go_fish/card_spec.rb` + `crazy_eights/card_spec.rb`)

- [ ] has a rank and suit
- [ ] cards of the same rank and suit are equal
- [ ] raises `InvalidRank` for an invalid rank
- [ ] raises `InvalidSuit` for an invalid suit
- [ ] `#value` returns the comparable value of the card
- [ ] `#to_s` returns the formatted card
- [ ] `#to_pathname` returns the formatted pathname
- [ ] `#objectify` turns a card string into a `Card` (kept from the CE spec; no longer CE-only)

### `spec/models/deck_spec.rb` (new — merged from `go_fish/deck_spec.rb` + `crazy_eights/deck_spec.rb`)

- [ ] has 52 cards when created
- [ ] `#top_card` deals the top card (a `Card`) and reduces `cards_left` by one
- [ ] `#top_card` gives a unique card each time
- [ ] `#shuffle` shuffles the deck
- [ ] `#empty?` returns true when the deck is empty
- [ ] `#empty?` returns false when the deck is not empty

### Existing specs to update in place (references only — no new behavior, just `GoFish::Card` → `Card` etc.)

- [ ] `spec/models/go_fish/game_spec.rb`
- [ ] `spec/models/go_fish/player_spec.rb`
- [ ] `spec/models/crazy_eights/game_spec.rb`
- [ ] `spec/models/crazy_eights/player_spec.rb`
- [ ] `spec/models/crazy_eights/william_spec.rb`
- [ ] `spec/models/crazy_eights/round_result_spec.rb`
- [ ] `spec/system/games_spec.rb`
- [ ] `spec/support/helpers/play_turn_helper.rb`

(`GoFish::Card`/`CrazyEights::Card`/`GoFish::Deck`/`CrazyEights::Deck` are explicit scoped
constant lookups — they will raise `NameError` once the per-game classes are deleted, even
though bare `Card`/`Deck` inside `module GoFish` / `module CrazyEights` source files resolve
fine via lexical fallback. Every spec/helper file above must be updated to the bare constant.)

## Related specs (regression check)

- `spec/models/go_fish/game_spec.rb`, `spec/models/crazy_eights/game_spec.rb` — exercise
  `Deck`/`Card` indirectly through game play
- `spec/system/games_spec.rb` — full-stack smoke test, catches any missed reference
- Full `bundle exec rspec` — the actual go/no-go per the BRAVE breakdown's shuffle spike
