# 0005 — A calendar view in the metric detail screen

- **Date:** 2026-07-07
- **Status:** Accepted
- **Area:** `MetricDetailView`, `Views/MetricDetails/Calendar/*`

## Context

The detail screen only ever showed a scrolling chart — a bar chart for
number/duration, a stacked bar for category. A chart answers *"how much, over
time?"* well, but not *"did I log this, and what, on which day?"* There was no
glanceable map of the month.

For **category** it was worse than neutral: the stacked bar crams every choice
into one bar per day, so with a handful of labels it collapses into an
unreadable smear — you can't read a single day out of it.

| Category — the classical stacked chart | Same data — the day-pie calendar |
| --- | --- |
| ![category stacked chart](assets/0005-category-chart.png) | ![category calendar](assets/0005-category-calendar.png) |

## Decision

Make a month **calendar** a first-class detail view. The whole month reads at a
glance: which days have data, streaks and gaps, and — for category — *what* was
logged each day. Which view a metric gets depends on its shape:

- **binary, datetime → calendar only.** Their natural question is
  "which days?", so the chart is dropped entirely (filled vs. empty cells).
- **number, duration → chart ⇄ calendar toggle,** defaulting to the **chart**
  (magnitude and trend are the point). The calendar marks each day that has an
  entry.
- **category → chart ⇄ calendar toggle,** opening on the **calendar**. Each day
  is a pie of that day's choices, with a legend to filter labels — because the
  chart is the unreadable case above.

The number/duration calendar — logged days at a glance:

![number calendar](assets/0005-number-calendar.png)

## Alternatives

- **Chart only** — the prior state. Fine for trend, blind to per-day coverage,
  and unreadable for category.
- **Calendar only, for every type** — loses magnitude and trend for
  number/duration, where the chart still earns its place.

## Notes

- binary and datetime have no toggle — there is nothing to switch to.
- Category seeds its legend (all labels shown) and flips to the calendar **once**
  on appear, guarded so a re-appear never wipes the user's label toggles.
- The calendar cells (`CalendarDayCell`, `DayPieFillView`, `DaySolidFillView`)
  and the scroller (`CalendarScrollView`) were extracted from the original
  `BinaryCalendarView` so all types share one calendar.

## Reproduce

Render the `MetricDetailView` previews: **Category Single/Multiple** open on the
pie calendar; **Heart Rate** / **Sleep** show the chart with the toggle in the
top-right; flip it to see the calendar.
