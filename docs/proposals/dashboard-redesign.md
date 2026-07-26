# Dashboard redesign — a today-first checklist, not a report

- **Date:** 2026-07-07
- **Status:** Proposed — a *for later* path, not implemented
- **Area:** `Views/DashboardView.swift`, `Views/ContentView.swift`,
  `Views/MetricView/`
- **Relates to:** [decision 0004](../decisions/0004-contrast-corrected-tint.md)
  (tint ownership), [metric-detail redesign](metric-detail-redesign.md)
  (shares the delta/streak vocabulary)

A UX pass over the dashboard and the metric card, sketched during a review
session. Nothing here is committed; it's the direction to reach for when the
dashboard gets its next major iteration. If a slice ships, record the actual
decision as a new ADR and link back here.

## Problems with the current screen

1. **It answers "what am I tracking?" but not "what should I do right
   now?"** A tracker's daily loop is *logging*, yet nothing on screen says
   which trackers were already logged today and which are waiting. The
   dashboard is a report; the job to be done is a checklist.
2. **Every metric gets equal real estate.** A binary "Medication taken"
   (one bit/day) gets the same ~150pt card as "Sleep" (a rich time series).
   With 6–8 trackers, half the dashboard lives below the fold and the
   uniform rhythm gives the eye nothing to prioritize.
3. **The headline value has no time anchor.** "8,432" — today? this week?
   last entry? The window logic exists (`MetricViewFactory.value(for:)`
   windows to the aggregation bucket) but the UI never names the window.
4. **Logging always costs a sheet.** Even a binary answer is: tap `+` →
   sheet → tap Yes → dismiss. Three interactions for one bit.
5. **Small signals.** The toolbar `square.and.pencil` reads "compose a
   note", not "new tracker"; sort is hard-fixed at `createdAt` descending
   (no pinning, no reorder); the feedback card sits inside the list as a
   peer of the user's own data.

## Current layout

```
┌────────────────────────────────────┐
│ My Trackers                   [✎]  │  ← "compose" glyph for "add"
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ 👟 DAILY STEPS           [ + ] │ │  ← no time anchor on value;
│ │    8,432                       │ │    every log opens a sheet
│ │  ██████████▒▒▒                 │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ 💊 MEDICATION TAKEN      [ + ] │ │  ← one bit of data, same
│ │    Taken                       │ │    150pt as a time series
│ │  · ● ● ○ ● ● ● ● ● ● ● ● ● ●   │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ 🌙 SLEEP                 [ + ] │ │  ← logged 4 days ago —
│ │    7h 30m                      │ │    indistinguishable from
│ │  ▂ ▄ ▆ █ ▅ ▃ ▆                 │ │    a fresh card
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ 💬 Enjoying ArperBird? …       │ │  ← feedback card as a peer
│ └────────────────────────────────┘ │    of user data
└────────────────────────────────────┘
```

## Proposed skeleton

The one organizing idea: **the dashboard is a today-first checklist that
empties as you log**. Cards migrate from "TO LOG" to "LOGGED ✓" as entries
land, so finishing the day is a visible act, and the progress line under the
title gives it a finish line.

```
╭─────────────────────────────────────────────╮
│   MONDAY, JULY 7                            │ ◀ date eyebrow — anchors
│   My Trackers                        ( + )  │   everything to "today";
│   ◔ 3 of 5 logged today                     │   plain "+" replaces ✎;
│                                             │   progress line gives the
│  ┈┈ TO LOG ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈ 2 left ┈┈  │   day a finish line
│                                             │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓  │ ◀ unlogged-today cards
│  ┃ ╭────╮ MEDICATION              today? ┃  │   float to the top,
│  ┃ │ 💊 │                                ┃  │   full saturation
│  ┃ ╰────╯ ┌───────────┐  ┌────────────┐  ┃  │
│  ┃        │  ✓ Taken  │  │  ✕ Missed  │  ┃  │ ◀ binary logs INLINE:
│  ┃        └───────────┘  └────────────┘  ┃  │   one tap, no sheet
│  ┃  · · · · ● ● ○ ● ● ● ● ● ● ▢          ┃  │ ◀ 14-day dot strip,
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │   today = hollow square
│                                             │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓  │
│  ┃ ╭────╮ SLEEP                   [ + ]  ┃  │
│  ┃ │ 🌙 │ — not logged yet               ┃  │ ◀ honest empty value,
│  ┃ ╰────╯                                ┃  │   not a fake "0h 0m"
│  ┃   ▂ ▄ ▆ █ ▅ ▃ ▆ ▇ ▄ ▅ ▆ ░            ┃  │ ◀ today's bin hollow —
│  ┃   M T W T F S S M T W T F↑today       ┃  │   the chart shows the
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │   gap to fill
│                                             │
│  ┈┈ LOGGED ✓ ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈  │ ◀ done section: slightly
│                                             │   receded, still tappable
│  ┌───────────────────┐ ┌─────────────────┐  │
│  │ 👟 STEPS · today  │ │ ☕ COFFEE ·today│  │ ◀ glanceable types
│  │ 8,432             │ │ 3 cups          │  │   (gauge, small counts,
│  │ ██████████▒▒ 84%  │ │ ▃▅▂▇▃▅█  [ + ]  │  │   binary-done) pack into
│  │ goal 10,000       │ │                 │  │   a 2-up grid → the whole
│  └───────────────────┘ └─────────────────┘  │   day fits one screen
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │ 🧴 BREAKOUT TRIGGERS · this week      │  │ ◀ category keeps full
│  │ Sugar                                 │  │   width (stacked bar
│  │ ▓▓▓▓▓▓▓▓▒▒▒▒▒░░░░▒▒▒░░                │  │   needs it)
│  │ Sugar ▓ 9 · Period ▒ 6 · Stress ░ 4   │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐   │
│    ⛽ GAS FILL-UP        last: Jul 3        │ ◀ occasional "datetime"
│  │  ····●····●····●····●·  every ~16d   │   │   metrics collapse to a
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │   quiet single row — they
│                                             │   don't belong in a
│         💬 Enjoying ArperBird?              │   daily checklist
│                                             │ ◀ feedback demoted to a
╰─────────────────────────────────────────────╯   plain footer link
```

## Card anatomy, redesigned (full-width rich card)

```
        ┌ tint = metric.displayColor, glow shadow kept as identity ┐
  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃                                                   ┃
  ┃  ╭─────╮   SLEEP · today            ╭─────────╮   ┃ ①
  ┃  │ 🌙  │   7h 30m  ▲ +40m           │  + Log  │   ┃ ②
  ┃  ╰─────╯                            ╰─────────╯   ┃
  ┃                                                   ┃
  ┃      ▂  ▄  ▆  █  ▅  ▃  ▆  ▇  ▄  ▅  ▆  ░           ┃ ③
  ┃      ┄┄┄┄┄┄┄┄┄┄┄┄┄┄ goal ┄┄┄┄┄┄┄┄┄┄┄┄┄            ┃
  ┃      27  28  29  30  1   2   3   4   5   6  7     ┃ ④
  ┃                                                   ┃
  ┃  🔥 5-day streak                  avg 7h 10m      ┃ ⑤
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

1. **Time-anchor chip on the title** ("· today" / "· this week") — surfaces
   the aggregation window `MetricViewFactory.value(for:)` already computes
   but never names.
2. **Value + delta vs. personal average.** One glance answers "is this
   normal for me?", which a raw number never does. "+ Log" becomes a
   labeled pill, not a bare `+` (bigger target, self-explaining — softens
   the need for `AddEntryTip`). Delta stays neutral-colored until a
   polarity flag exists (same caveat as the detail proposal).
3. **Today's bin drawn hollow/dashed until logged** — the chart itself
   shows the gap you're supposed to fill.
4. **Real axis labels on the mini chart** (day numbers), so the sparkline
   is data, not decoration.
5. **Footer facts slot, per type:** streak for binary/habit, average for
   numbers, "usually every ~16d" for datetime.

## Compact card (2-up grid, glanceable types)

```
  ┌──────────────────────┐  ┌──────────────────────┐
  │ 💧 WATER · today     │  │ ☕ COFFEE · today    │
  │                      │  │                      │
  │ 1.8 L                │  │ 3 cups   ⊖ [ 3 ] ⊕   │ ◀ stepper INLINE for
  │ ████████▒▒▒▒  72%    │  │ ▃▅▂▇▃▅█              │   small-range numbers
  │ of 2.5 L      [ + ]  │  │                      │
  └──────────────────────┘  └──────────────────────┘
```

This reuses a decision the editors already made:
`MetricInputFactory.numberStyle(for:)` knows which metrics are
"stepper-simple" (≤10 steps). Those same metrics are exactly the ones that
can log **on the card** with zero sheets — the sheet stays for sliders,
pickers, and duration wheels.

## Staleness, instead of silence

```
  normal card                      neglected card (no entry in 3+ days)
  ┏━━━━━━━━━━━━━━━━━━┓            ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
  ┃ ❤️ HEART RATE    ┃              ❤️ HEART RATE
  ┃ 72 bpm · today   ┃            │ 68 bpm · 4 days ago  │ ◀ desaturated tint,
  ┃ ~~~~/\~~~/\~~    ┃              ~~~~/\~~ ░ ░ ░ ░       chart fades to
  ┗━━━━━━━━━━━━━━━━━━┛            └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   hollow bins
```

The color system from decision 0004 gives this for free: staleness = mixing
`displayColor` toward gray, so "alive" cards are literally more colorful
than abandoned ones. Gentle — no red badges, no guilt notifications.

## Interaction map (what changes, what stays)

```
                 tap card ──────────────▶ MetricDetailView      (kept)
                 swipe ◀── ─────────────▶ Delete                (kept)
                 long-press ────────────▶ context menu + NEW:
                                          "Pin to top", "Log for yesterday"
  NEW  tap Yes/No / stepper on card ────▶ append(point) directly, card
                                          animates TO LOG → LOGGED ✓
  NEW  drag to reorder (edit mode) ─────▶ manual sort order
       toolbar ✎ ───────────────────────▶ becomes plain (+)
```

## What stays

The per-metric color glow (the app's visual signature), the flat card list
over any tab structure, swipe-to-delete, and the factory architecture —
everything above is expressible as new mappings in `MetricViewFactory`
(config + behavior → card density and footer fact) rather than a rewrite,
the same slots philosophy as the detail proposal.

## Implementation notes

- **Impact-per-effort order:** (1) the today-first split + inline binary
  logging — it converts the dashboard from a report into a checklist and is
  the cheapest slice: a partition of the existing `@Query` results
  ("has an entry with today's date?") plus one new card variant; (2) the
  time-anchor chip and delta/streak footer (shares aggregation code with
  the detail redesign's stats strip); (3) the 2-up grid, inline stepper,
  and staleness treatment as polish.
- **Section membership must be cheap.** "Logged today" is derivable per
  metric from `data.last`; avoid scanning full `data` arrays on every list
  render — a computed `lastEntryDate` (or denormalized field, if it ever
  shows up in a query predicate) keeps the partition O(metrics).
- **Manual sort order** needs a persisted `sortIndex` on `Metric` — that's
  a `SchemaV2` lightweight migration per the recipe in
  `MetricMigrationPlan.swift`, worth batching with any other pending model
  change.
- **The 2-up grid vs. `List`:** swipe actions and drag-reorder are `List`
  affordances; a `LazyVGrid` loses them. Either keep one `List` and make a
  "pair row" wrapper for compact cards, or accept context-menu-only delete
  inside the grid section. Decide before building the grid, not after.
