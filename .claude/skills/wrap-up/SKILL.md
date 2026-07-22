---
name: wrap-up
description: >-
  Wrap up a coding session by folding what was learned into the project's
  committed docs — AGENTS.md and docs/*.md. Prunes stale or now-false notes,
  adds only non-obvious, durable learnings (gotchas, rationale, in-flight
  status), and keeps AGENTS.md under 200 lines by extracting detail into docs/.
  Use this whenever a session is ending and the docs should reflect what
  changed — triggered by "/wrap-up", "wrap up", "end of session", "update the
  docs before I go", "capture what we learned", "document this session", or any
  request to record session context for the next session or a teammate. Reach
  for it even when the user just says they're done for the day.
---

# Wrap-up

## Why this exists

`AGENTS.md` and `docs/` are the project's memory between sessions. They are the
first thing the next session — or a new apprentice — reads, and `AGENTS.md` is
loaded into context on *every* session, so every line there spends a slice of a
finite budget. That makes wrap-up an **editing** task, not a logging one. You
are curating a high-signal reference, not keeping a diary. A doc that grows by
accretion becomes noise; a doc that stays lean and true stays worth reading.

**Scope:** this skill touches only the repo's committed docs — `AGENTS.md` and
files under `docs/`. It does not manage the personal auto-memory system.

## The filter: what earns a place

Before writing anything, run each candidate through one question:

> Could a competent developer — or a future session — figure this out by
> reading the code, the tests, or `git log`?

If yes, leave it out. The code is the source of truth for *what* the system
does; docs exist for what the code **can't** tell you. Document only what is
both **non-obvious** and **durable**:

- **Gotchas, traps, and latent bugs** the code doesn't announce — the kind of
  thing that costs someone an hour. (See how `docs/testing.md` frames the `:js`
  tag trap: the symptom, then *why*.)
- **The "why" behind a decision** — rationale, tradeoffs, alternatives that were
  considered and rejected. Code shows the choice; only docs show the reasoning.
- **Conventions RuboCop and the tests won't catch** (e.g. the ≤ 7-line rule).
- **Cross-cutting orientation** — where things live, how the layers relate.
- **In-flight status** — what's done and what's next on a multi-session effort,
  as a durable handoff, not a play-by-play of the conversation.

Leave out:

- Restatements of what the code plainly shows.
- Anything a commit message or `git log` already records.
- Conversation-specific trivia ("we tried X, then Y, then it worked").
- Anything already documented — **update it in place** instead of duplicating.

## Prune as much as you add

A good wrap-up usually *removes* something. Stale docs are worse than missing
ones because they actively mislead — someone trusts them and loses time. Hunt
for content the session made false:

- A "latent bug" or gotcha note for something you just fixed → delete it (or
  move it to a "fixed in …" line only if the history matters).
- A progress/status note that's now out of date → rewrite it to the new state,
  don't stack a second note beside it.
- A convention or path that changed → correct it.

## Where things go

- **`AGENTS.md`** is the always-loaded index: high-level, cross-cutting, terse.
  Keep it **≤ 200 lines** (it's currently well under). It should point to
  detail, not contain all of it.
- **`docs/*.md`** is loaded on demand: detailed rules, rationale, per-game
  specifics, longer workflows. This is where depth belongs.

When `AGENTS.md` approaches 200 lines, or a section there has grown into
detailed prose, **extract that detail into a `docs/` file and leave a one-line
pointer** in the "Key context" list (the file already uses this pattern — match
it). Prefer extending an existing `docs/` file over creating a new one; a new
file is warranted only for a genuinely new topic.

For in-flight work, update the existing progress marker (e.g. the `Progress:`
line in `docs/improvement-1-breakdown.md`, or the status note in the relevant
`AGENTS.md` bullet) rather than adding a parallel one.

## Workflow

1. **Reconstruct the session.** What was actually done, decided, discovered, or
   fixed? Skim the diff / recent commits if it helps jog the specifics.
2. **Draft candidates and apply the filter.** For each thing you might record,
   ask the non-obvious-and-durable question. Most candidates should fail it.
3. **Reconcile with what's already there.** Open the docs the change touches.
   Is anything now stale (prune it) or already covered (update in place)?
4. **Place each survivor** — `AGENTS.md` for index-level, `docs/` for detail —
   matching the surrounding voice and format.
5. **Check the budget.** If `AGENTS.md` is at or near 200 lines, extract detail
   into `docs/` and leave a pointer.
6. **Summarize for the user** (see below).

## The summary

Close with a short, scannable report — one line per file, saying *what* changed
and *why* it earned a place:

```
Wrap-up complete:
- AGENTS.md — corrected the play_turn gotcha (the '10' truncation is fixed).
- docs/improvement-1-breakdown.md — moved Progress to Deliverable D complete.
- docs/testing.md — added the serialize-caching note (bit us this session).

Left out: the RuboCop config tweak (visible in the diff) and the three refactor
attempts (git history covers them).
```

Naming what you deliberately left out is part of the value — it shows the
filter ran, and lets the user override if they wanted something kept.
