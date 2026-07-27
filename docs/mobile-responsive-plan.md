# Make the game board mobile-friendly (CSS-only responsive pass)

## Context

The app's game board is currently desktop-only and unusable on phones. `.game`
(`app/assets/stylesheets/components/game.css`) is a fixed two-column CSS grid
(`"players feed" / "hand books"`, `height: 100dvh`) with a hardcoded side-column width and
**zero media queries** anywhere in the codebase. On a narrow screen the feed column gets
crushed, hands render as a non-wrapping `.flex` row that overflows off-screen with no scroll
affordance, and inner `overflow: auto` panels trap scrolling. The lobby/sidebar lean on
Optics' built-in responsiveness and are out of scope here.

Goal: make **gameplay** work on phones down to **~390px wide, portrait-first**, with **no
visual redesign** — targeted responsive CSS only. Both games (`GoFishGame`,
`CrazyEightsGame`) share the identical `.game`/`.panel` structure, so a single set of CSS
changes fixes both. **No markup changes and no JavaScript** in this pass.

### Locked decisions
- **Layout:** single stacked column, order players → feed → hand → books, one vertical scroll.
- **Cards:** wrap to multiple rows (hand, books, and players' book cards). Fan/overlap
  neutralized on mobile so every card is fully visible/tappable-sized.
- **Action bar:** the existing dropdown+submit play form, pinned to the viewport bottom,
  compacted and touch-sized. Cards stay display-only.
- **Orientation:** portrait-first; landscape phones reflow with the same rules.
- **Scope:** CSS only. Tap-to-select-a-card is explicitly deferred (see Follow-up).

## Breakpoint

Single mobile query, added to `game.css` (and the other component files as needed):

```css
@media (max-width: 768px), (orientation: landscape) and (max-height: 600px) { … }
```

768px is the conventional phone/portrait-tablet cutoff and covers every target device
(iPhone SE 375, iPhone 12–16 390, Pro Max 430, portrait tablets). The
`orientation: landscape` + `max-height: 600px` clause catches landscape phones (which are
>768px wide) so they reflow too, without pulling real tablets/desktops into the mobile layout.

## Changes (all scoped inside the mobile query unless noted)

### 1. `app/assets/stylesheets/components/game.css`
- `.game` → `grid-template-columns: 1fr;` `grid-template-areas: "players" "feed" "hand" "books";`
  `height: auto;` `min-height: 100dvh;` and add `padding-bottom` sized to the pinned action
  bar's worst case (Crazy Eights has 3 selects + submit — see note in #4).
- `.game__players`, `.game__feed` → `overflow: visible; height: auto;` so the document/body is
  the single scroll container (required for the stacked column to scroll as one and for
  mobile-Safari `dvh` URL-bar collapse to give back height).

### 2. `app/assets/stylesheets/components/panel.css`
- `.panel--players .panel__content`, `.panel--feed .panel__content` → `overflow: visible;`
  (feed's content is currently `overflow: hidden`, which would clip the game-feed messages in
  single column).
- Card-row wrapping:
  - `.panel--hand .panel__content > .flex` → `flex-wrap: wrap; row-gap: var(--op-space-small); column-gap: var(--op-space-2x-small);`
  - `.panel--books .panel__content` → same wrap treatment.
  - `.panel--players .book-collection` → same wrap treatment (players' book cards live in
    `.book-collection` inside each accordion, **not** a bare `.flex`).
- Remove the orphaned fan-compensation margin on mobile:
  `.panel--hand .panel__content`, `.panel--books .panel__content` → `margin-inline-start: 0;`

### 3. `app/assets/stylesheets/components/playing-card.css`
- `.playing-card` → `margin-inline-start: 0;` (neutralize the `-25px` fan overlap so wrapped
  cards don't overlap and every card is fully visible — the desktop fan is untouched because
  this is inside the query).
- `.playing-card--large:hover { margin-top: 0; }` (the hover-lift does nothing on touch and
  hurts once overlap is gone) and add `touch-action: manipulation;` to kill the tap delay.
- Optional: shrink hand cards to fit more per row via
  `.panel--hand .playing-card--large { --gf-card-height: <smaller>; }` — keep rendered width
  ≥ ~44px for touch. (CSS-only, no markup class change.)

### 4. Pinned action bar — `.panel--feed .panel__content > form`
The play form is a **direct child** of `.panel__content` in both partials (Go Fish wraps only
the header in `div.timer`; the form stays a direct child), so this selector works for both.
- `position: fixed; inset-inline: 0; bottom: 0; z-index: <above content>;
  background: var(--op-color-primary-plus-eight); padding: var(--op-space-small);`
- Compact the stacked selects: `display: flex; flex-wrap: wrap;` on the form (or its input
  wrapper) with constrained select widths so a 2–3-select bar stays short and never overflows
  390px. This both reclaims vertical space and makes the `.game` `padding-bottom` spacer
  predictable.
- **`position: fixed` gotcha to verify:** a fixed element breaks (becomes absolute) if any
  ancestor has `transform`/`filter`/`perspective`/`will-change`/`contain`. `--animate-duration`
  suggests animate.css is in use; confirm no animated/transformed ancestor sits between the
  form and `<body>` (the feed `#message-stream` area is the likely injection point). `overflow:
  auto`/`hidden` ancestors do **not** clip a fixed child, so those are fine.

## Verification

Manual (primary — this is visual/responsive work):
1. `bin/dev`, open a Go Fish game and a Crazy Eights game (start each so the board renders).
2. In browser devtools responsive mode, test at **390px** (iPhone 14), **375px** (SE), and a
   landscape phone (e.g. 844×390). Confirm for both games:
   - Zones stack players → feed → hand → books; the whole page scrolls as one column (no
     trapped inner scrollbars, feed messages not clipped).
   - A full hand wraps to multiple rows with visible gaps; no card runs off-screen; no overlap.
   - The action form is pinned to the bottom, fully visible, selects + submit are comfortably
     tappable, and nothing is hidden behind it (books zone clears the bar).
   - Crazy Eights' 3-select form (player/rank/suit) still fits and the spacer clears it.
3. Confirm desktop (>768px) is visually unchanged — the fan overlap, 2-column grid, and hover
   lift all still work.
4. `bin/rubocop` (CSS isn't linted, but keep the branch clean).

Tests: no RSpec changes needed for a CSS-only pass; existing system specs run under
`rack_test` and don't assert layout. Run `bundle exec rspec` to confirm nothing regressed.

## Follow-up — **done** (was deferred out of this pass)

Tap-to-select-a-card interaction: tapping a hand card highlights it (`.is-selected`) and the
turn buttons commit the selection. Shipped for **Rummy** as the `rummy-turn` Stimulus
controller (`app/javascript/controllers/rummy_turn_controller.js`) — see `docs/games/rummy.md`,
"Card selection UI". Go Fish and Crazy Eights still use dropdowns.
