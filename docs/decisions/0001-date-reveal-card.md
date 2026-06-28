# 0001 — Date reveal card: dashed empties over a faked history

- **Date:** 2026-06-28
- **Status:** Accepted
- **Area:** Tracker creation reveal (`TrackerDoneView`, `EventCalendarMiniChart`)

## Context

The closing "You're all set!" reveal shows the new tracker seeded with sample
data so the chart looks alive. Fine for most types — but the **date** type's
calendar shows real month/day labels, so fake seed data makes a brand-new tracker
look like it already holds anniversaries the user never logged. A real date
tracker starts **empty** and fills one real entry at a time.

## Options

**Option C — dashed empties + one real "today" cell** *(chosen)*

![Option C](assets/date-reveal-option-c.png)

**Option E — fade trail: a faded history ghosts in toward today** *(rejected)*

![Option E](assets/date-reveal-option-e.png)

## Decision

Ship **C**, reject **E**.

**E is too fake.** Dimming the cells doesn't change what they say — they still
show concrete dates (JUIN 19/22/25/28) as if four anniversaries were logged. The
fade dresses up the fabrication instead of removing it, and misrepresents the
real product.

**C is honest.** Its one filled cell is a *real* date (today), sitting where the
user's first entry will land — so the reveal quietly teaches the affordance. The
solid cell against dashed slots still reads as alive and finished.

Cost also favours C: a one-line seed change in `doneMetric()`
(`[.datetime(.now)]`). E would also need `fadeTrail` threaded through
`MiniChartFactory` to reach the real reveal.

## Consequences

- `doneMetric()` special-cases `.date`; every other type keeps `Metric.fakeData`.
- The persisted card still starts empty — only the reveal is seeded.
- `EventCalendarMiniChart.fadeTrail` stays (default off, used only by the
  rejected-option preview) so this decision is reproducible. Removable if unused.

## Reproduce

Renders of two previews in `TrackerDoneView.swift`: `#Preview("Date")` (C) and
`#Preview("Date — fade trail (Option E)")` (E). Re-render via Xcode or the
`RenderPreview` MCP tool and replace the PNGs in `assets/`.
