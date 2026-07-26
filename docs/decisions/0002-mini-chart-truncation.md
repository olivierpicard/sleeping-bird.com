# 0002 — Mini-charts show the latest, not all

- **Date:** 2026-06-29
- **Status:** Accepted
- **Area:** `BarMiniChart`, `LineMiniChart`, `MiniChartFactory`

## Context

A card's mini-chart has fixed width. As data grows, fitting *every* point
squeezes bars/points until they blur together.

```
Before — squeeze everything in (100 points)
│▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏▏│   illegible
```

## Decision

Keep only the **latest** items that fit at a minimum width; drop the oldest
and trailing-align (newest on the right).

```
After — keep latest that fit, drop the rest (100 points)
│            ▁ ▃ ▂ ▅ ▄ █ ▆ ▇ █ ▅ ▆ █│   readable, newest-right
 └ older dropped ┘
```

Sparse data doesn't stretch — points hold a max spacing instead:

```
3 points                 3 points (no stretch)
│▆       █       ▄│  →   │        ▆ █ ▄│
```

A single point can't draw a line, so it gets a flat line + end dot:

```
│ ──────────────● │
```

## Cumulative bars

Cumulative number/duration bars aggregate into the metric's own period
(daily when unset) — same day keeps growing the last bar, not a new one.

```
Two entries, same day          One in-progress bar
10 ─┐    20 ─┐          →       30 ─┐
    █        █                      █
```

## Consequences

- Older history is still in the detail view; only the *mini* chart truncates.
- New `MetricAggregator.bins(component:)` overload + `TemporalBucket.bucketComponent`.
- Reveal/sample data seeds more days so charts read as real trends.
