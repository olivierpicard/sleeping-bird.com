# 0009 — Backdated entries: a nudge-arrow date row, expanding to a day wheel

- **Date:** 2026-07-25
- **Status:** Accepted — implemented in `Views/MetricEditor/MetricEntrySheet.swift`
- **Area:** Manual data entry (`MetricInputFactory`, `Views/MetricEditor/`)

## Context

Entries could only ever be logged for "now". `MetricInputFactory.make` stamps
the timestamp itself, inside each case:

```swift
onAdd: { onAdd(.number(Date(), $0)) }   // ← the user never sees or picks this
```

Five of the six configs do this. `.datetime` is the exception — there the
picked date *is* the value, so `_DatePickerEditor` already writes an arbitrary
date and needs nothing from this work.

Two call sites present that sheet: `DashboardView` (card "+" and the "Add
entry" context menu) and `MetricDetailView` (toolbar "+").

Forgetting to log and wanting to fill in yesterday is the single most obvious
gap in a habit tracker, so the date had to become visible and editable.

## Decision

A **44pt date row above every editor**, defaulting to Today, whose centre
label opens a **single-drum day wheel** by growing the sheet in place.

```
   ┌──────────────────────────────────────────┐
   │                 ╶╶╶╶╶╶                   │
   │      ◂        Today        ▹             │
   │      ▲          ▲          ▲             │
   │      │          │          └─ dimmed: no future
   │      │          └─ tap = expand the wheel
   │      └─ one day back (hold to repeat)    │
   │  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌  │
   │         ⊖          8          ⊕          │   ← existing editor,
   │                glasses                   │      untouched
   │   ┌────────────────────────────────────┐ │
   │   │               Save                 │ │
   │   └────────────────────────────────────┘ │
   └──────────────────────────────────────────┘
```

Today stays preselected, so the common path is still **open → Save**, with no
added taps.

### The label rewrites itself to stay short

```
      ◂        Today          ▹      0 days back, ▸ dimmed
      ◂      Yesterday        ▸      1 day
      ◂     Wed 23 Jul        ▸      2–6 days: weekday + date
      ◂       12 Jun          ▸      this year: no year
      ◂     8 Dec 2025        ▸      earlier: year appears
      ◂    Wed 23 Jul  •      ▸      • = this day already has an entry
```

### Tapping the label grows the sheet

```
   ┌────────────────────────────────┐        ┌────────────────────────────────┐
   │            ╶╶╶╶╶╶              │        │  ◂   Wed 22 Jul  •  ⌃      ▸   │
   │    ◂      Today  •   ▹         │        │  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌   │
   │  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌   │  tap   │        Sun 19 Jul              │
   │       ⊖      0      ⊕          │  ────▶ │        Mon 20 Jul              │
   │           glasses              │  label │        Tue 21 Jul              │
   │  ┌──────────────────────────┐  │        │   ▸▸▸  Wed 22 Jul  ◂◂◂         │
   │  │          Save            │  │        │        Thu 23 Jul              │
   │  └──────────────────────────┘  │        │        Yesterday               │
   └────────────────────────────────┘        │        Today            ┃      │
                                             │  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╋╌╌╌   │
            250 + 56 = 306pt                 │       ⊖      0      ⊕   ┃      │
                                             │           glasses      ┃      │
                                             │  ┌─────────────────────╋────┐  │
                                             │  │        Save        ┃     │  │
                                             │  └─────────────────────────┘  │
                                             └────────────────────────────────┘
                                                    486pt   ┗━ hard stop, no future
```

Two detents with a `selection:` binding. The editor stays mounted below the
whole time — see the state trap under *Rejected: wheel presentation*.

No separate "Done": the label's chevron flips to `⌃` and tapping it again
collapses the sheet. The picked day applies live, and Save is visible the whole
time, so a confirm step would have been decoration.

### One drum, not three

A stock `DatePicker(.wheel)` spins day / month / year. Nobody backdating a
glass of water needs a year drum, and three drums allow invalid combinations
(31 February, next week). One relative-day drum, capped at today, is half the
height and cannot produce an invalid date. The last two rows read as words
("Yesterday", "Today").

The drum needs a finite end, so it holds **365 days**. That reads as "a year
back" and keeps the label list cheap enough to build once per presentation. The
"Jump to a date… 📅" escape hatch sketched during design was **not** built — it
is a second date control for a case (backfilling further than a year) that the
app has no other reason to support yet.

### No time picker

The stored clock time is invisible everywhere except `.datetime` metrics:

| Surface | What it shows |
|---|---|
| Charts | `MetricAggregator` bins by day / week / month — 09:00 and 23:00 share a bar |
| Recent Entries | `entryRow` renders `"Yesterday"` + `"2026"`, never a time |
| Calendar | one cell per day |
| `.datetime` only | `entryDisplayText` formats `time: .shortened` — the time **is** the measurement |

So the row picks a **day**, never a time, and `.datetime` metrics get **no
row at all** (their existing picker already does both).

### Backdated points are stamped at noon

Not `startOfDay`. Midnight sits on the day boundary, where a timezone or DST
shift can slide the point into the neighbouring day and move it to the wrong
bar. Noon is immune.

## Options considered

### The date control

| Option | Why it lost |
|---|---|
| **Horizontal day strip** (`21 22 23 [24]` + 📅) | The real contender. ±4 days in *zero* taps and a dot under every filled day of the week — but 80pt of permanent chrome in a 250pt sheet, and it still needs a 📅 escape for the far past. What we give up is the at-a-glance "which days did I miss", which belongs in the detail calendar, not an entry sheet. |
| **Menu on a `Today ⌄` label** | Cheapest to build, +30pt. The date reads as a word, not a control — too easy to miss. |
| **Segmented `Today / Yesterday / Date…`** | Very readable, +52pt, but "Date…" opening a sheet-on-sheet is clumsy. |
| **Date-first step, then the value** | No sheet growth and it echoes the Tracker Creation flow, but it taxes *every* entry with an extra tap, including the ~95% that are "now". |
| **Draggable time ruler under Save** | One gesture to scrub months, but landing on an exact day is fiddly and it's an unfamiliar control. |

The arrows won on quiet: 44pt collapsed, and ◂ ▸ speaks the same language as
the ⊖ ⊕ sitting directly below them.

### Wheel presentation

- **Inline expand (chosen)** — matches Apple Calendar / Reminders, and the
  editor is never unmounted.
- **Swap the wheel in for the editor body** — keeps the height fixed, and
  that's the trap: every editor holds its value in its own `@State`
  (`_StepperEditor.value`). Branching the wheel in *replaces* the editor in
  the view tree, SwiftUI tears it down, and the dialled-in value resets to the
  default. Viable only as an **overlay over a still-mounted editor** — a rule
  someone would have to remember forever.
- **A second sheet on top** — two grabbers, two dismiss gestures, and the card
  shrinks behind. Far too heavy for picking a day.

## Implementation notes

| File | Change |
|---|---|
| `Views/MetricEditor/MetricEntrySheet.swift` | **new** — owns the chosen day, draws the row and the wheel, computes the detents |
| `Metric/MetricInputFactory.swift` | `date:` parameter replacing the five hardcoded `Date()`, plus the `EditorHeight` table |
| `Metric/Metric.swift` | `DataPoint.date` and `DataPoint.daysBack` |
| `Views/DashboardView.swift`, `Views/MetricDetails/MetricDetailView.swift` | present `MetricEntrySheet` instead of the factory directly |
| the nine `_*Editor.swift` files | `.presentationDetents` removed from each body; their previews now read `MetricInputFactory.EditorHeight` so the numbers exist once |

`date:` is a **closure**, not a `Date` — evaluated when the user taps Save, so a
sheet left open for a while doesn't record the moment it was opened. Its default
`{ Date() }` means the pre-existing behaviour survives for any caller that
doesn't care.

Free wins: `MetricDetailView` already recomputes on `metric.data.count`, so a
backdated point re-renders charts and the calendar with no new plumbing. The
`entry_added` PostHog event carries `days_back`, so how much this feature is
actually used is measurable.

Row details that shipped: `.sensoryFeedback(.selection)` per step, arrows tinted
through `Color.readableControlTint` like the rest of the flow, and a single
VoiceOver element ("Date, Today") with the **adjustable** trait so swipe up/down
changes the day — better than exposing three separate buttons.

**Hold-to-repeat on ◂ was dropped.** A `Button` fires on touch-up regardless of
how long it was held, so layering a repeat gesture over it double-counts the
final step, and the workarounds all depend on gesture-vs-action ordering that
SwiftUI doesn't guarantee. Reaching far back is what the wheel is for — which is
the same argument this ADR already makes against the day strip.

## Open questions

- **Saving onto a day that already has an entry.** Append a second point
  (today's behaviour, and what shipped — right for water: 6 then 2 = 8), or
  replace it (right for weight: you meant to correct 70kg, not weigh 70 *plus*
  71), or branch on `MetricBehavior` (`.cumulative` appends, `.snapshot`
  replaces). **Still unresolved** — shipping as "append" is the status quo, not
  a decision. The • dot in the label is a partial mitigation either way: you see
  the collision before you save.
- **Whether 365 days is the right cap.** "Since the tracker was created" would
  be more honest now that `Metric` *does* have `createdAt` (it's the dashboard's
  sort key), and would need no migration — but it makes the drum length vary per
  tracker, which is a different feel worth deciding on deliberately.

## Related

- [0005 — A calendar view in the metric detail screen](0005-calendar-in-detail.md)
  — its day cells already track a tapped date, which would be a natural second
  entry point later. Deliberately out of scope here.
