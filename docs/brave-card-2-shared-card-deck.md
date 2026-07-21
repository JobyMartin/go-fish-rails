# BRAVE Breakdown: Card 2 — Collapse the duplicated `Card` / `Deck` into one shared primitive

## Brainstorm

**The work:** `GoFish::Card` and `CrazyEights::Card` are byte-for-byte identical except that
`CrazyEights::Card` adds a `self.objectify(card_string)` parser. `GoFish::Deck` and
`CrazyEights::Deck` differ only in *how they build the deck*: Go Fish shuffles ranks within
each suit (`Card::RANKS.shuffle.map`, so cards stay grouped by suit), Crazy Eights builds in
order then `.shuffle`s the whole deck. Goal: **one shared `Card`, one shared `Deck`**, both
games reusing them, specs staying green, and each STI subclass keeping its explicit serializer.

**What we confirmed by reading the code:**
- **The shuffle difference is almost certainly an artifact.** The two deck specs
  (`spec/models/*/deck_spec.rb`) are themselves byte-for-byte identical and assert only
  "52 cards," "shuffle changes order," and "empty?" — **nothing pins the per-suit grouping.**
  (The dev recalled moving the shuffle only to make a test green.)
- **`objectify` is generic, not CE-specific.** Called in exactly one place
  (`crazy_eights_game.rb:8`) and it just parses a `"Rank Suit"` string. Safe to give every game.
- **Confirmed-dead code to remove while here:** `Deck#create_stacked_deck` (zero callers
  anywhere), and the leftover comments `# RANKS = %w( J Q K A )` and `# @cards = []`.

**Scope boundaries:** No user-facing change. Not persisting game-over, not touching
serialization coders, not adding new game behavior — just concentrating duplicated primitives.

## Approach

**Namespace — flat top-level `::Card` / `::Deck`** at `app/models/card.rb` and
`app/models/deck.rb`. Chosen over a `Cards::` module because these are two tiny classes and
the domain objects already sit flat under `app/models/`; top-level reads as "shared primitives,
not owned by a game." Bonus: the bare `Card` / `Deck` references inside `module GoFish` /
`module CrazyEights` (in `game.rb` and `player.rb`) resolve to the new top-level constants
via Ruby's constant lookup once the per-game copies are deleted — **zero caller edits** there.

**Shuffle — Approach A: unify to one whole-deck shuffle and delete the fork entirely.**
No strategy parameter. This passes the deletion test hardest and is simplest for a future
third game. The card's "shuffle strategy is passed in" wording becomes the *fallback*
(Approach B), used only if the spike goes red.

**Reuse:** the existing green specs are the safety net — this is "keep green," not new behavior.
Merging the two identical `deck_spec.rb` files into one shared example is the quality extra.

**Serialization stays intact:** `serialize :game_state, coder: GoFish::Game` is untouched.
`Game.load` → `Card.load` now resolves to `::Card`. `game_state` stores rank/suit *hashes*,
not class names, so nothing persisted references the old namespace — no migration, no data risk.

**The spike / go-no-go:** apply Approach A, then run the **full** `bundle exec rspec` (not just
the deck specs). Green ⇒ done. Red ⇒ fall back to Approach B or ship just the `Card` collapse.

**Mid-way checkpoint:** collapse `Card` first and run the suite; then `Deck` and run the suite —
two small green checkpoints rather than one big-bang debug.

**How the user would know something's wrong:** a red spec — no runtime error states to design,
since behavior is unchanged.

## Value

- **Business/product:** removes two shallow modules kept in sync by hand; the documented
  "prep for a third game" stretch item. A third game reuses the primitive instead of forking a
  third copy.
- **User:** none directly — pure internal quality.
- **Priority:** not sprint-essential; a targeted tech-debt paydown from the rails-audit
  (Medium, Code Design). Sequenced last of the three cards because it touches every domain spec.
- **Optimize for:** **quality** — the dead-code cleanup and deck-spec consolidation are cheap
  while already in these files, and a third game benefits most from the tidiest primitive.

## Estimate

- **2 points — X-Small (~under 2 hours)**, + standard 15% review/pairing buffer (fits the
  available half-afternoon). Mechanical: delete two files, lower two to top-level, strip dead
  code, lean on existing specs.
- **Top risks (all low):**
  - Untested reliance on Go Fish's per-suit ordering — *low / low*; caught immediately by the
    full suite, fallback is Approach B.
  - Bare-constant resolution surprise after deleting a per-game copy — *low / low*; suite catches it.
  - Serialization round-trip — *very low / low*; `game_state` stores rank/suit hashes, not classes.
- **Incremental shipping:** yes — collapse `Card` and ship, then `Deck` as a follow-up. Each is
  independently green.
- **Sequencing:** no blocker. Card 1 done; Card 3 (authorization) is independent.
- **Timebox guardrail:** the shuffle spike is the go/no-go — if red, don't improvise a fix under
  time pressure; fall back to B or ship the `Card` half.

## Implementation Plan

- [ ] Create top-level `app/models/card.rb` (`::Card`) from `GoFish::Card`, including
      `self.objectify` for all games; drop the dead `# RANKS = ...` comment.
- [ ] Delete `app/models/go_fish/card.rb` and `app/models/crazy_eights/card.rb`.
- [ ] Update `crazy_eights_game.rb:8` `CrazyEights::Card.objectify` → `Card.objectify`.
- [ ] Run `bundle exec rspec` — confirm green (Card checkpoint).
- [ ] Create top-level `app/models/deck.rb` (`::Deck`) using a single whole-deck shuffle
      (Approach A); drop `create_stacked_deck` and the `# @cards = []` comment.
- [ ] Delete `app/models/go_fish/deck.rb` and `app/models/crazy_eights/deck.rb`.
- [ ] Run `bundle exec rspec` — the shuffle spike / go-no-go (Deck checkpoint). If red, fall
      back to Approach B or ship just the Card collapse.
- [ ] Merge the two identical `spec/models/*/deck_spec.rb` (and `card_spec.rb`) into shared
      top-level specs; keep the CE `#objectify` example. **This is the drop-first step if the
      timebox gets tight** — the collapse itself is complete without it; card the merge for later.
- [ ] `bin/rubocop` and a final full `bundle exec rspec`.
