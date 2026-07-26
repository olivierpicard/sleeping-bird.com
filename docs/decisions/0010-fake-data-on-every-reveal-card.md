# 0010 — Fake data on every reveal card, date and binary included

- **Date:** 2026-07-26
- **Status:** Accepted — supersedes [0001](0001-date-reveal-card.md)
- **Area:** Tracker creation reveal (`TrackerCreationFlow.doneMetric()`, `TrackerDoneView`)

## Context

[Decision 0001](0001-date-reveal-card.md) made the date path (and later binary)
an exception to the reveal's sample data: instead of `Metric.fakeData`, each was
seeded with a single *real* point — today — so the calendar showed dashed empty
slots leading into one filled cell. The reasoning was honesty: invented month/day
labels would read as anniversaries the user never logged.

Testing the shipped screen showed the opposite. The lone "today" cell reads as
**a real entry the tracker already holds** — which it isn't, since the persisted
metric starts empty. Users came away thinking the tracker was already recording,
not that it was waiting for their first entry. The dashed slots didn't carry the
"example" meaning on their own; they just looked like a mostly-empty calendar
with one genuine row in it.

## Options

**Option A — fill date and binary with `Metric.fakeData`** *(chosen)*

Every path seeds the reveal the same way. The calendar shows several dates the
user never picked.

**Option B — keep the today-only seed, add an "Example" badge to the card**
*(rejected)*

Marks the sample data explicitly, on every type rather than two.

## Decision

Ship **A**.

**The volume of data is the signal.** A spread of dates the user never entered is
self-evidently not theirs — they know they just created this tracker seconds ago.
One date, on the other hand, is exactly what a first real entry would look like,
so it invites the wrong reading. 0001 got the direction of the confusion backwards:
more fabricated data is *less* confusing here, not more.

**B was rejected as the wrong fix for now.** A badge is chrome that argues with the
card instead of letting it read correctly on its own, and it would have to appear on
every reveal — a heavier change to solve a problem the seed alone can solve. It
remains available if the "example" reading turns out to be weak for other types too.

## Consequences

- `doneMetric()` loses its `.date` / `.binary` special case — every kind now falls
  through to `Metric.fakeData`, so the switch only tunes *how many days* to seed.
- The persisted card still starts empty; only the reveal is seeded. Unchanged.
- The date reveal no longer previews the "your first entry lands here" affordance
  that 0001 valued. Accepted: the dashed slots weren't teaching it clearly enough
  to justify the cost.
- `EventCalendarMiniChart` keeps rendering dashed empty cells when data is short —
  it just won't be exercised by the reveal any more.
