# Testing

TDD is a requirement on this project. This doc captures the expected workflow and how the
suite is laid out.

## Workflow (outside-in TDD)

1. **Start with a system spec** written from the user's perspective — what the player sees
   and does.
2. As you implement to make it green, you'll hit the need for new models or new methods.
   **Before writing that code, write the model/unit spec** for it.
3. End state: a **small number of green system specs** proving correct behavior from the
   user's standpoint, backed by **comprehensive model specs** for the individual methods.

Keep each `it` block to **≤ 7 lines** (same limit as methods).

## Running

```sh
bundle exec rspec                       # full suite
bundle exec rspec spec/models/go_fish   # a directory
bundle exec rspec path/to/spec.rb:42    # a single example by line number
```

## Spec layout

The specs mirror the two-layer architecture (see `docs/architecture.md`):

- `spec/models/*_game_spec.rb` — the Active Record STI wrappers (`GoFishGame`, etc.).
- `spec/models/go_fish/`, `spec/models/crazy_eights/` — the plain-Ruby domain objects.
  This is where the bulk of the coverage lives.
- `spec/system/` — Capybara feature specs (the user's-perspective layer).
- `spec/requests/`, `spec/views/`, `spec/helpers/`, `spec/jobs/` — as named.
- `spec/support/helpers/` — reusable helpers (`create_game_helper`, `play_turn_helper`,
  `sign_in_helper`, `sign_up_helper`, `playwright_helper`, etc.). Reach for these instead
  of re-writing setup.
- `spec/factories/` — FactoryBot factories.

## Arranging a persisted game in a spec

Setting up a started game trips people up because of the STI + serialization split:

- `create(:game, type: 'GoFishGame')` (or `'CrazyEightsGame'`) builds the AR subclass; the
  `:game` factory's `initialize_with` handles the STI. The empty `:go_fish_game` /
  `:crazy_eights_game` factory stubs are unused — ignore them.
- Add players with `create(:player, game:)` (the `:player` factory auto-creates a `User`).
  A `game_state` only exists after `game.start`, which builds the domain object, deals, and
  **already calls `save!`** — no separate save needed.
- `game.game_state` returns the **same in-memory domain object** on every call until
  `game.reload` (the `serialize` coder caches the deserialized value). So you can grab it
  once, mutate a hand (e.g. `state.current_player.hand = []`), and `play_turn` sees it.
- Domain actions can mutate the current player mid-call (e.g. Go Fish's `fish_and_skip`
  switches turns), so capture the player/index you're asserting on *before* the call.

### Staging a hand leaves duplicates in the deck

**Forcing a hand does not remove those cards from the deck.** `deal!` has already dealt a
shuffled 52-card deck, so `state.current_player.hand = [ Card.new('3', 'Hearts'), ... ]`
*adds* a second 3 of Hearts to the game — the original is still sitting in the stock. Any
later deck draw can hand it back, and an assertion like "the melded card left my hand" then
fails because the duplicate is still there. It failed roughly **8% of runs** (4 staged cards
out of ~48 remaining) — frequent enough to erode trust in the suite, rare enough that several
clean runs prove nothing.

Rummy system specs avoid this by staging through `start_rummy_game_with_state`
(`spec/support/helpers/rummy_turn_helper.rb`), which yields the `game_state` and then prunes
every staged card out of the deck:

```ruby
start_rummy_game_with_state do |state|
  state.current_player.hand = [ Card.new('3', 'Hearts'), Card.new('4', 'Hearts') ]
  state.drawn_this_turn = true
end
```

Stage through the helper rather than by hand. If you add a similar helper for another game,
prune the deck the same way — and note that a spec which never draws from the deck will pass
either way, so the bug hides until someone adds a draw.

### Known flake: `spec/models/game_spec.rb:124` (Go Fish)

**If the suite goes red here, it is almost certainly not your change.** `Game#play_go_fish …
'plays a turn'` deals a real shuffled deck, asks for `'A'`, and asserts the hand is exactly
`8` — which only holds when the opponent happens to hold **exactly one** Ace. Two Aces and
they hand over both, so you get `9` and a failure. Measured at **2 of 30 seeds (~7%)**.

Same root cause as the staged-hand trap above — an unpinned random deck — just from the
other direction: nothing is staged, so the deal decides the assertion.

Two things this costs you if you don't know it. First, a passing run proves nothing, so
"green before, red after" reads as a regression when the deck simply rolled differently.
Second, **re-running with the same `--seed` does not reproduce it across branches**: the seed
shuffles the example *list*, so adding or removing any example anywhere changes the order and
the deal. To pin blame, re-run the single example across a spread of seeds on both branch
states:

```sh
for s in $(seq 1 30); do bundle exec rspec spec/models/game_spec.rb:124 --seed $s; done
```

The fix is to pin that spec's deck the way the Rummy helpers do; carded, not done.

### Undiagnosed: a `:js` intermittent in `spec/system/games_spec.rb`

`games_spec.rb:309` (Rummy, "taking from the discard pile shows the move in the game feed")
failed once in three consecutive full-suite runs and has never reproduced — not in isolation,
and not across the whole file at the original seed. **It is not the staged-deck flake above**:
that spec goes through `start_rummy_game_with_state`, which prunes the duplicates. Most likely
Playwright timing under full-suite load, but that is inference, not a diagnosis.

If you hit it, **capture the whole failure message** — the first sighting was lost to a
`| tail -6` on the suite output, which is why there's nothing better written here.

This session added a **second** `:js` sighting of the same shape, at `spec/system/offlines_spec.rb:33`
("renders an offline alert"), failing on `click_on 'Start game'`. It passed 2 of 3 isolated runs
and has not recurred. Same inference — Playwright timing, not a diagnosis.

## N+1 queries fail the suite

`config/environments/test.rb` sets `Bullet.raise = true` with **no safelist**, so any N+1,
unused eager load, or missing counter cache that a spec exercises raises
`Bullet::Notification::UnoptimizedQueryError` and fails that example. This is the project's
only automated guard against N+1s: Bullet is **off by default in development**
(`BULLET=1 bin/dev` opts in), so the suite is where you find out.

Two consequences worth knowing:

- **A red spec pointing into a view is often a Bullet finding, not a broken expectation.** The
  message names the model and association and suggests the `includes`.
- **Bullet needs two or more records to see a pattern.** A spec with a single record cannot
  trigger it, so passing specs are not proof a page is N+1-free at scale — that is what
  `perf:measure` is for (`docs/leaderboard.md`).

A safelist existed briefly while the leaderboard was deliberately N+1. It is gone, and it
should stay gone: safelists are scoped by association, not by request path, so they silence
every page at once.

## Arranging a *finished* game in a spec

Leaderboard/stats specs need games with `started_at` **and** `ended_at`, which the `:player`
factory's `:in_finished_game` trait provides. It updates the game *after* creating the player,
because `Player`'s `not_started` validation rejects joining a game that has already started —
the same order the real app uses.

Its duration is `FinishedGame::DURATION` (`spec/support/finished_game.rb`), shared with every
spec that asserts on the resulting time. **Derive expected times from that constant**, never
hardcode them: `'120h 0m'` silently encoded "5 games × 24 hours" with the 24 living in a
different file, so changing the trait would have broken specs for no visible reason.

## Beware substring matches in `have_content`

`expect(page).to have_content '0%'` **passes on a page showing `100%`** — it's a substring
match, so a win-percentage assertion like this can assert essentially nothing. Row-scoping
doesn't save you either. Match the cell exactly:

```ruby
expect(find('tr', text: username)).to have_selector 'td', exact_text: text
```

Worth mutation-testing any assertion of this shape: change the fixture so it *should* fail,
and confirm it does. This one was caught only that way, after passing for several runs.

## Drivers and the `:js` gotcha

System specs default to `rack_test`. Tags switch the driver
(`spec/support/capybara_drivers.rb`):

- `:js`     → Playwright headless (Chromium)
- `:chrome` → Selenium Chrome (headed)
- `:firefox`→ Playwright Firefox

**Keep specs on `rack_test` unless they truly need a browser.** A system spec that depends
on JavaScript/Turbo behavior but is *not* tagged `:js`/`:chrome` will fail — that missing
tag is the most common cause of a confusing system-spec failure here.

Assets are compiled once per run via `rails spec:prepare` (guarded by an
`ASSET_PRECOMPILE_SUCCESSFUL` env flag in `rails_helper.rb`); if assets fail to compile the
suite aborts before running. That includes the **esbuild JS bundle** (`spec:prepare` chains
`yarn install` → `yarn build`), so **you don't need to `yarn build` by hand before running
`:js` specs** — a Stimulus change is picked up by the next `rspec` invocation. Don't go
looking for the task in this repo: `spec:prepare` is rspec-rails' own rake task, which
delegates to `test:prepare`, which jsbundling hooks the JS build onto. Grepping the codebase
for it finds only its two mentions in `spec/rails_helper.rb` and this file. The flag is
per-*process*, so the rebuild happens once at the first system spec of a run, not between
examples.

**A `:js`-driven sign-in can silently fail** — the spec stays on `/session/new` (no
exception raised), so the *next* assertion fails on unrelated missing content, which reads
like a totally different bug. This is a real race in this dev environment's cold
Puma/Playwright startup (the very first request(s) in a fresh headless-browser process),
not a bug in the auth code — do not "fix" it by touching `SessionsController`.
`sign_in` (`spec/support/helpers/sign_in_helper.rb`) already retries up to 3 times,
re-attempting the login while it's still looking at the "Sign in" button. For the same
underlying reason, prefer `expect(page).to have_css(...)` right after any `click_on`/
`click_button` that triggers a page transition and before you do raw ActiveRecord state
manipulation — the click returning is not a guarantee the resulting page has finished
loading.

## Selecting elements in system specs

Don't select on CSS classes (`have_css '.game__hand img.playing-card'`) — those are styling
hooks and get renamed during CSS refactors for reasons that have nothing to do with what the
spec is verifying. Add a `data-testid` to the element in the view instead, and select on it
with the `data_test(name)` helper (`spec/support/helpers/test_element_helper.rb`, included in
system specs) rather than hand-writing the `[data-testid="..."]` string. `Capybara.test_id` is
also configured to `'data-testid'` (`spec/support/capybara_testid.rb`). The same applies to
JS-driven state classes (`.is-selected`, `.feed-open`): the Stimulus controllers that toggle
them also set a parallel `data-*` attribute (`data-selected`, `data-feed-open`) so specs assert
behavior through that attribute instead of the styling class.

Asserting on rendered card *order* (e.g. after a sort action) means reading `img[src]`
values — but Propshaft fingerprints every asset with a content hash
(`k_clubs-846574d4.svg`), so a direct `eq` against the plain card filename always fails.
Strip the hash instead of hand-rolling a regex inline in the spec: see
`RummyTurnHelper#hand_card_prefixes`/`#card_filename_prefix`
(`spec/support/helpers/rummy_turn_helper.rb`) for the pattern.

## Assert persisted state, not just the DOM, for actions that write to the database

A passing `have_css` after a `click_button`/`click_on` only proves the page re-rendered — it
doesn't prove the write reached the database. Any system-spec action that triggers a
`play_turn`/`start`/similar POST should also assert against a freshly-reloaded record (e.g.
`game.reload.game_state.current_player.hand.size`), the same way the model specs already do
(`expect { game.play_turn(...) }.to change { state.round_results.size }.by(1)`). Prefer
deriving expected counts/deltas from the test's own setup (e.g. `hand_before - 1`, or a
`change { ... }.by(1)` block) over hardcoding the resulting number — it documents *why* the
number is what it is and survives changes to deal sizes or setup data.

## Tightening a client-side guard can strand a server-validation spec

A spec that drives a **disabled-until-valid** button to reach *server* validation is coupled to
that button's enable threshold, and nothing names the coupling. Tighten the guard and the spec
can no longer perform the click that got it to the server, so it fails somewhere unrelated —
looking like the validation broke when only the button did.

This is not hypothetical: raising the Rummy meld button's threshold from "≥ 1 card selected" to
"≥ 3" broke `'shows an error message when melding an invalid combination'`, which had been
selecting **two** mismatched cards to trigger `Rummy::InvalidMove`. The fix is to keep the
spec's original intent — three still-invalid cards, so it clears the button and *still* exercises
the server path — not to relax the guard or retarget the spec at the button.

So: after changing any client-side enable rule, **run the whole suite, not just the specs you
wrote.** The casualty is by definition in a spec you weren't thinking about, and both specs are
legitimate — one pins the button, one pins the server. Keep them that way rather than collapsing
them into a single client-side assertion.

## CI caveat

`.github/workflows/ci.yml` runs **only** RuboCop + security scans (Brakeman,
bundler-audit, importmap audit). **It does not run RSpec.** Green CI ≠ passing tests — you
must run the suite locally. `marsh_grass` is available for chasing down flaky tests.
