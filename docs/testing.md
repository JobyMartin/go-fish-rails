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

## CI caveat

`.github/workflows/ci.yml` runs **only** RuboCop + security scans (Brakeman,
bundler-audit, importmap audit). **It does not run RSpec.** Green CI ≠ passing tests — you
must run the suite locally. `marsh_grass` is available for chasing down flaky tests.
