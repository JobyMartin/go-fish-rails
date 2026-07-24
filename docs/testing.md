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
suite aborts before running.

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

## CI caveat

`.github/workflows/ci.yml` runs **only** RuboCop + security scans (Brakeman,
bundler-audit, importmap audit). **It does not run RSpec.** Green CI ≠ passing tests — you
must run the suite locally. `marsh_grass` is available for chasing down flaky tests.
