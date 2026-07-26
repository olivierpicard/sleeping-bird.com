# Binary vs. date trackers — habit or event, not Bool or Date

- **Date:** 2026-07-26
- **Status:** Proposed — a *for later* path, not implemented
- **Area:** `TrackerCreation/TrackerKind.swift`,
  `TrackerCreation/TrackerIntentView.swift`,
  `TrackerCreation/TrackerSuggestion.swift`,
  `Views/MetricEditor/Binary/`, `Views/MetricView/`
- **Relates to:** [decision 0003](../decisions/0003-intent-based-creation.md)
  (intent-first creation), [decision 0001](../decisions/0001-date-reveal-card.md)
  and [decision 0010](../decisions/0010-fake-data-on-every-reveal-card.md)
  (the date/binary reveal cards),
  [dashboard redesign](dashboard-redesign.md) (inline logging — overlaps, see
  "Divergence" below)

Started from a plain question: **do `binary` and `date` both need to exist?**
They look almost identical to a user — two calendar-shaped trackers answering
what seems like the same question. The answer is yes, but not for the reason
the code currently believes. Nothing here is committed; if a slice ships,
record the actual decision as a new ADR and link back here.

## The question, and why the current answer is wrong

The code splits the two kinds by **payload**:

| | `binary` | `date` |
|---|---|---|
| DataPoint | `.binary(Date, Bool)` | `.datetime(Date)` |
| Editor | 👍 / 👎 two cards (`_BinaryEditor`) | wheel picker, date + time, past-only |
| Mini chart | `TrailingCalendarMiniChart` — yes *and* no days colored | `EventCalendarMiniChart` — occurrences only |
| Can log a "no" | yes, explicitly | no such concept |
| Multiple per day | meaningless | natural |

That framing makes the explicit "no" the thing that justifies `binary`. It
doesn't hold up: **~95% of the time a user will never log a "no."** Absence of
a yes already means no. A whole editor exists to serve the 5%.

The split that *does* hold up is **cadence**:

```
"Did I, today?"        daily slot, one per day, streaks     → meds, gym, floss, drinks, plants
      ↕  a different question — not a different data type
"When did it happen?"  episodic, irregular, gaps matter     → period, migraine, gas, haircut
```

- **Habit** earns its kind through the *daily slot*. Every day is an
  expectation, so an empty cell is a signal ("you missed Tuesday"), and
  streaks exist at all.
- **Event** earns its kind through the *gap*. There is no expectation, so an
  empty day means nothing; what matters is time-since-last and interval. A
  "yes today" is a wrong-shaped answer for a migraine — usable, but it isn't
  the question being asked.

Both survive. Neither survives for the reason it was built.

## Vision 1 — binary has no editor

A yes/no tracker should never open a sheet. Logging a habit is one bit; it
should cost one tap, on the card itself.

```
BEFORE                                  AFTER

┌─────────────────────┐                 ┌─────────────────────┐
│ 💊 Meds        [+]  │                 │ 💊 Meds             │
└─────────────────────┘                 │ ▓▓▓░▓▓▓ streak 4    │
          │ tap                         │ ┌─────────────────┐ │
          ▼                             │ │  Mark as done   │ │ ◀ one tap, no sheet
   ┌─────────────┐                      │ └─────────────────┘ │
   │  sheet      │                      └─────────────────────┘
   │ 👍     👎   │  ◀ 2 cards for                    │ tapped
   │             │    a 5% case                      ▼
   └─────────────┘                      │ ✓ Done today   undo │
          │ tap Yes                     └─────────────────────┘
          ▼ dismiss
```

Three interactions become one, and the card states today's status instead of
hiding it behind a `+`.

**Where the "no" goes.** It stays in the model — the `falseLabel` plumbing is
shallow (a field in `MetricSchema`, one color branch at
`TrailingCalendarMiniChart:39`, a display value in `MetricViewFactory:86`), so
nothing needs a schema migration. It just stops being a first-class gesture.
Options, unresolved: a small secondary "skipped" affordance, a long-press, or
only through the detail view's entry list. The 5% shouldn't cost the 95% a tap.

### Divergence from the dashboard redesign

[dashboard-redesign.md](dashboard-redesign.md) sketches the same idea but keeps
**two** inline buttons (`✓ Taken` / `✕ Missed`). This proposal argues for
**one** ("Mark as done"), on the reasoning above. Whichever ships, the two docs
should converge — don't build both.

## Vision 2 — variation pills phrased as questions (A/B test)

**The curated suggestion chips stay exactly as they are.** This is about the
*variation* pills — the format row under the preview card in
`TrackerIntentView`, built by `intentFormat(for:name:emoji:color:)`, that lets
a resolved idea be re-shaped before continuing.

Today those pills are named after the **data shape**. The candidate names them
after the **question the user arrived with**:

```
CURRENT (data shape)              CANDIDATE (questions)

  # A number                        How much?
  ⏱ Time spent                      How long?
  ✓ Yes / No                        Is it done?
  🎯 Daily goal                     My goal
  📅 A date                         When it happened?
  ☰ Pick from a list                Which one?
```

Hypothesis: a user picking between variations isn't choosing a storage format,
they're recognizing their own question. "Is it done?" may be more natural than
"Yes / No" — and it is also the phrasing that finally makes the
habit-vs-event split legible, since "Is it done?" and "When it happened?" read
as obviously different questions where "Yes / No" and "A date" read as near
neighbours.

**Run this as an A/B test**, not a swap. The current labels are shorter and
may well win — question phrasing costs horizontal room in a scrolling pill row,
and "My goal" breaks the interrogative pattern the others set. Measure with the
existing PostHog wiring: `tracker_format_switched` already fires on every pill
change, and `tracker_kind_selected` on continue, so the arms can be compared on
switch rate and on which format actually gets shipped.

Open: a third arm could keep both — question as a section header over
shape-named pills.

## What stays

- Both `TrackerKind` cases, both `DataPoint` cases, both calendars. The
  question was whether to delete one; the answer is no.
- The curated suggestion chips, untouched.
- Internal naming (`binary`, `date`) can stay as-is. The habit/event
  vocabulary is **copy** — the variation pills above, plus the two reveal
  recaps, which today say "Track yes or no each day" and "Save a date on
  calendar", i.e. payload language where the user needs question language.

## Order of attack

1. **Binary's inline "Mark as done"** — users feel it every single day, and
   it's the largest interaction saving in the app.
2. **Habit/event copy** in the reveal recaps — cheap, and it makes the two
   kinds legible for the first time.
3. **Variation-pill A/B test** — needs a real sample, so it trails the other
   two.
