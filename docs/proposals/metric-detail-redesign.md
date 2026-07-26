# Metric detail redesign — one adaptive screen with slots

- **Date:** 2026-07-07
- **Status:** Proposed — a *for later* path, not implemented
- **Area:** `Views/MetricDetails/MetricDetailView.swift`
- **Relates to:** [decision 0005](../decisions/0005-calendar-in-detail.md)
  (calendar in detail), [decision 0004](../decisions/0004-contrast-corrected-tint.md)
  (tint ownership), [dashboard redesign](dashboard-redesign.md)
  (shares the delta/streak vocabulary)

A UX pass over the detail screen, sketched during a review session. Nothing
here is committed; it's the direction to reach for when the detail screen gets
its next major iteration. If a slice ships, record the actual decision as a new
ADR and link back here.

## Problems with the current screen

1. **The hero value and the chart are disconnected.** Scrubbing happens at
   mid-screen, but the number that reacts is far above, past the controls row.
   The eye ping-pongs. (Apple Health solves this with a selection callout
   *inside* the chart.)
2. **Logging is buried.** For a tracker, "add today's entry" is *the* action —
   currently a small `+` in the nav bar, visually equal to Edit. The
   `AddEntryTip` exists partly because this button is easy to miss.
3. **No insight layer.** The screen shows raw data (chart + list) but never
   answers "am I doing well?" — no average, no streak, no delta vs. last
   period. That's the emotional payoff of tracking.
4. **The controls row shape-shifts.** Range picker ⇄ month selector swap in
   place depending on chart mode, so the row's meaning changes under the
   finger (and the trailing-padding hack shows the two controls fighting for
   space).
5. **The number-metric calendar wastes information.** Days are just
   filled/empty dots, but the values exist — an intensity heatmap
   (GitHub-style) would show effort for free. *(Cumulative only — see the
   snapshot variant below.)*
6. **Recent Entries is a dead end** — hard cap of 8, no "view all", no
   grouping, delete-only.

## Current layout (number metric)

```
┌────────────────────────────────────┐
│ ‹ Back                    [+] [⚙]  │  ← log entry = tiny nav button
├────────────────────────────────────┤
│ ❤️ HEART RATE                      │
│                                    │
│  72  bpm                           │  ← reacts to scrubbing…
│ Jul 7, 2026 · Latest               │
│                                    │
│ [ 1M │ 6M │ 1Y ]        [▦|📅]     │  ← morphs into month selector
│ ┌────────────────────────────────┐ │
│ │      ▄   ▆     █               │ │
│ │  ▂ ▄ █ ▆ █ ▄ ▂ █ ▆   ▄         │ │  ← …but you scrub down here
│ │ ─┴───┴───┴───┴───┴───┴─        │ │
│ └────────────────────────────────┘ │
│                                    │
│ RECENT ENTRIES                     │
│ ┌────────────────────────────────┐ │
│ │ Today                   72 bpm │ │
│ │ Yesterday               68 bpm │ │
│ │ July 5                  74 bpm │ │  ← hard stop at 8, no "all"
│ └────────────────────────────────┘ │
└────────────────────────────────────┘
```

## Proposed skeleton (number, cumulative)

```
┌────────────────────────────────────┐
│ ‹ Back        Heart Rate ❤️    [⋯] │  ← Edit/Delete under one menu
├────────────────────────────────────┤
│                                    │
│  72 bpm      ╭─────────────╮       │
│  Jul 7 ·     │ ▲ 6% vs Jun │       │  ← delta chip: instant "how
│  Today       ╰─────────────╯       │    am I doing" signal
│                                    │
│ [  1M  │  6M  │  1Y  ]             │  ← range picker alone, full
│ ┌────────────────────────────────┐ │    width, never morphs
│ │        ┌─────────┐             │ │
│ │        │ 74 bpm  │             │ │  ← selection callout lives
│ │        │ Jun 12  │             │ │    IN the chart (lollipop)
│ │        └────┬────┘             │ │
│ │      ▄   ▆  ●  █               │ │
│ │  ▂ ▄ █ ▆ █ ▄│▂ █ ▆   ▄         │ │
│ │ ─┴───┴───┴──┴┴───┴───┴─        │ │
│ └────────────────────────────────┘ │
│                                    │
│ ┌─────────┐┌─────────┐┌─────────┐  │
│ │ AVG     ││ BEST    ││ STREAK  │  │  ← stats strip: the insight
│ │ 71 bpm  ││ 58 bpm  ││ 12 days │  │    layer, recomputed with
│ └─────────┘└─────────┘└─────────┘  │    the range
│                                    │
│ HISTORY              ‹  July  ›    │  ← calendar demoted to its
│ ┌────────────────────────────────┐ │    own section — no more
│ │  M  T  W  T  F  S  S           │ │    chart/calendar toggle
│ │  ░  ▓  █  ▓  ·  ░  █           │ │
│ │  █  █  ░  ▓  █  ▓  ·           │ │  ← intensity heatmap, not
│ │  ▓  ░  █  █  ▓  █  ◌           │ │    just filled/empty dots
│ └────────────────────────────────┘ │
│                                    │
│ RECENT ENTRIES          View all › │
│ │ Today                   72 bpm  │
│ │ Yesterday               68 bpm  │
│                                    │
│        ╭──────────────────╮        │
│        │   ＋ Log entry    │        │  ← tinted pill, pinned above
│        ╰──────────────────╯        │    safe area, always reachable
└────────────────────────────────────┘
```

### Rationale per move

- **Delta chip next to the hero value.** Computed from the current vs.
  previous bucket window (data `MetricAggregator` already produces). Respect
  `MetricBehavior`: for `.cumulative` compare totals, for `.snapshot` compare
  averages — and for metrics where "down is good" a polarity flag would be
  needed eventually, so start neutral-colored.
- **Selection callout inside the chart.** Keep the hero value pinned to
  "latest/today" and let scrubbing annotate the chart itself. Kills the eye
  ping-pong and makes the hero value a stable anchor instead of a moving
  target. `chartXSelection` already gives the date; it's an `.annotation` on
  the selected `BarMark`.
- **Kill the chart/calendar segmented toggle.** Chart and calendar answer
  different questions ("how much?" vs. "how consistently?") — show both,
  stacked, instead of making the user choose. Also deletes the morphing
  controls row, the `monthProgress` plumbing shared between selector and
  calendar, and the trailing-padding hack. The month selector moves into the
  calendar section header where it belongs. *(This supersedes the toggle from
  decision 0005 — the per-type calendar treatment there still stands.)*
- **Stats strip.** Three tiles driven by the same `bins` already computed:
  average (or total for cumulative), best, and current streak. Streak is *the*
  retention mechanic for binary/habit metrics and `filledDays` already exists
  for it.
- **Pinned "Log entry" pill** in the tracker's `tint` (via
  `readableControlTint`, consistent with decision 0004). Nav bar keeps only a
  `⋯` menu holding Edit — two same-weight nav buttons make the primary action
  look secondary.
- **"View all" on Recent Entries** pushing a full grouped list. The cap of 8
  stays on the detail screen; it just stops being a wall.

## Per-type variants — one skeleton, three slots

**Not** different screens. One skeleton with three slots that swap based on
`config` + `behavior` + `goal` — the same philosophy as
`MetricViewFactory`/`MetricInputFactory`. Navigation, toolbar, entries list,
and log-pill stay identical everywhere. What changes per type: **the hero**,
**the chart's mark type**, and **which stats tiles render**.

| Config | Hero | Chart mark | Stats tiles | Delta chip compares |
|---|---|---|---|---|
| number **cumulative** (steps) | total + delta | bars | Total · Avg/day · Best | sums |
| number **cumulative + goal** (dailyGauge) | today's **ring** | bars + goal line | Hit rate · Streak · Avg | hit rate |
| number **snapshot** (weight, HR) | latest + trend | **line + points** | Latest · Avg · Min–Max | averages |
| duration | same as its behavior, `h m` formatting | per behavior | per behavior | per behavior |
| binary / datetime / category | see below | calendar-first | Streak / distribution | — |

### Binary ("Alcohol-free days")

```
┌────────────────────────────────────┐
│ ‹ Back  Alcohol-free days 🌿   [⋯] │
├────────────────────────────────────┤
│                                    │
│  Alcohol-free   ╭──────────────╮   │  ← hero = today's (or the
│  Jul 7 ·        │ 🔥 12-day     │   │    selected day's) answer,
│  Today          │    streak    │   │    trueLabel straight from
│                 ╰──────────────╯   │    BinaryConfig; the streak
│                                    │    sits hero-adjacent — it's
│ ┌─────────┐┌─────────┐┌─────────┐  │    the point of the metric
│ │ STREAK  ││ BEST    ││ JULY    │  │
│ │ 12 days ││ 21 days ││ 24/30 ✓ │  │  ← best-ever gives a target
│ └─────────┘└─────────┘└─────────┘  │    to beat; success rate
│                                    │    follows the shown month
│ HISTORY              ‹  July  ›    │
│ ┌────────────────────────────────┐ │  ← no range picker at all —
│ │  M   T   W   T   F   S   S    │ │    binary is calendar-only
│ │  ●   ●   ●   ✕   ●   ●   ●    │ │    (decision 0005); month
│ │  ●   ●   ●   ●   ●   ✕   ●    │ │    selector lives in the
│ │  ●   ●  (●)  ●   ●   ●   ●    │ │    section header
│ │  ●   ·   ●   ●   ◌   ◌   ◌    │ │
│ │                                │ │  ← (●) = selected day, taps
│ │ ● Alcohol-free   ✕ Had a drink │ │    drive the hero above
│ │ · No entry       ◌ Future      │ │
│ └────────────────────────────────┘ │  ← legend built from the
│                                    │    config's own labels
│ RECENT ENTRIES          View all › │
│ │ Today             Alcohol-free  │
│ │ Yesterday         Alcohol-free  │
│ │ July 5            Had a drink   │
│                                    │
│  ╭───────────────┬──────────────╮  │
│  │ ✓ Alcohol-free │ ✕ Had a drink │ │  ← split pill: one-tap
│  ╰───────────────┴──────────────╯  │    logging, no editor sheet
└────────────────────────────────────┘
```

- The `●` (true) / `✕` (false, muted) / `·` (no entry) / `◌` (future)
  treatment maps 1:1 onto `DaySolidFillView`'s `.filled`/`.muted`/`.empty`
  styles — the cells already exist; the legend is the new part, and it uses
  the metric's own `trueLabel`/`falseLabel`, not generic "yes/no".
- **Split log pill.** The binary editor is a two-button choice anyway, so
  lift it into the pill and log today in one tap. The `⋯` menu keeps a
  "backdate an entry…" escape hatch for past days.
- Stats: current streak (`filledDays` already exists), best-ever streak, and
  the success rate of the month currently shown — so paging the calendar
  back also answers "how was March?".

### Datetime ("Doctor Appointments")

```
┌────────────────────────────────────┐
│ ‹ Back  Doctor Appointments 🏥 [⋯] │
├────────────────────────────────────┤
│                                    │
│  2 events      ╭───────────────╮   │  ← hero = selected/today
│  Jul 7 ·       │ ⏱ last was 4  │   │    count; the chip answers
│  Today         │   days ago    │   │    the datetime user's real
│                ╰───────────────╯   │    question: "when did this
│                                    │    last happen?"
│ ┌─────────┐┌─────────┐┌─────────┐  │
│ │THIS MO. ││ AVG GAP ││ TOTAL   │  │  ← cadence, not streak —
│ │ 4       ││ 9 days  ││ 23      │  │    events are occasional
│ └─────────┘└─────────┘└─────────┘  │    by nature
│                                    │
│ HISTORY              ‹  July  ›    │
│ ┌────────────────────────────────┐ │
│ │  M   T   W   T   F   S   S    │ │
│ │  ·   ●   ·   ·   ●²  ·   ·    │ │  ← ●² = count badge for a
│ │  ·   ·  (●)  ·   ·   ·   ·    │ │    multi-event day (the
│ │  ·   ●   ·   ·   ◌   ◌   ◌    │ │    current calendar hides
│ └────────────────────────────────┘ │    multiplicity entirely)
│                                    │
│ RECENT ENTRIES          View all › │
│ │ Today                    14:30  │  ← datetime rows show the
│ │ Today                    09:15  │    time-of-day; same-day
│ │ July 3                   11:00  │    events group naturally
│                                    │
│        ╭──────────────────╮        │
│        │  ＋ Log event now │        │  ← default timestamp = now,
│        ╰──────────────────╯        │    one tap; the editor sheet
└────────────────────────────────────┘    only opens to backdate
```

- Same calendar-only layout as binary, but the vocabulary shifts from
  *streak* to *cadence*: this-month count, average gap between events, and
  all-time total. "Last was N days ago" is the hero chip because recency is
  what an occasional-event tracker is for.
- The `●²` count badge surfaces multiplicity the current
  `datetimeFilledDays` set throws away (it's a `Set<Date>` of days, not
  counts).

### Category ("Mood")

```
┌────────────────────────────────────┐
│ ‹ Back           Mood 😊       [⋯] │
├────────────────────────────────────┤
│                                    │
│  Happy         ╭──────────────╮    │  ← hero = today's (or the
│  Jul 7 ·       │ 14× in July  │    │    selected day's) choice —
│  Today         ╰──────────────╯    │    multi-choice joins labels;
│                                    │    chip = how often it
│ [  1M  │  6M  │  1Y  ]             │    recurs this month
│                                    │
│ DISTRIBUTION                       │
│ ┌────────────────────────────────┐ │
│ │ ● Happy  ████████████░░░░  14  │ │  ← one component replaces
│ │ ● Tired  ██████░░░░░░░░░░   7  │ │    BOTH the stats strip and
│ │ ○ Sad    ███░░░░░░░░░░░░░   3  │ │    CategoryLegend: each row
│ │ ● Calm   ██░░░░░░░░░░░░░░   2  │ │    is also a filter toggle
│ └────────────────────────────────┘ │    (○ = hidden below); bars
│                                    │    recompute with the range
│ HISTORY              ‹  July  ›    │
│ ┌────────────────────────────────┐ │
│ │  M   T   W   T   F   S   S    │ │
│ │  ◕   ◑   ●   ◕   ·   ◑   ●    │ │  ← day = pie of that day's
│ │  ●   ◔  (◕)  ●   ◑   ●   ◌    │ │    visible choices, wedge
│ │  ◑   ·   ●   ◕   ◌   ◌   ◌    │ │    colors = the row dots
│ └────────────────────────────────┘ │    above, via the same
│                                    │    CategoryPalette map
│ RECENT ENTRIES          View all › │
│ │ Today              Happy, Calm  │
│ │ Yesterday                Tired  │
│                                    │
│        ╭──────────────────╮        │
│        │   ＋ Log mood     │        │  ← with ≤4 choices this
│        ╰──────────────────╯        │    could expand into quick-
└────────────────────────────────────┘    pick chips on tap
```

- **Distribution replaces the numeric stats strip** — sums per label over
  the picked range, straight from `categoryEntries`. It answers "which
  choice dominates?", which the pie calendar alone can't (decision 0005's
  stacked-chart problem, solved without a stacked chart).
- **Distribution rows double as the legend filter.** Tapping a row toggles
  that choice in the calendar (the `○` dot marks a hidden one) — this
  merges `CategoryLegend` and the stats into one component instead of
  stacking three category widgets.
- The range picker stays (unlike binary/datetime) because the distribution
  is range-scoped; the calendar keeps its own month selector in the section
  header, so the two never fight over one row again.

### Goal metric (`dailyGauge` — "Pages read", goal 30)

```
┌────────────────────────────────────┐
│ ‹ Back        Pages read 📖    [⋯] │
├────────────────────────────────────┤
│      ╭───────────╮                 │
│     ╱             ╲    32 / 30     │  ← hero IS the gauge —
│    │    ◠◠◠◠◠◠     │   pages       │    same ring the dashboard
│    │   ●  107% ●   │               │    card shows, blown up.
│     ╲             ╱   Goal met 🎉  │    Today-first, because a
│      ╰───────────╯                 │    goal is a daily contract
│                                    │
│ [  1M  │  6M  │  1Y  ]             │
│ ┌────────────────────────────────┐ │
│ │ ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ goal 30 │ │  ← RuleMark at the goal;
│ │      █   █  ▓  █               │ │    bars ≥ goal in full
│ │  ▓ ░ █ ▓ █ ░│▓ █ ▓   ░         │ │    tint, misses at ~40%
│ │ ─┴───┴───┴──┴┴───┴───┴─        │ │    opacity — met/missed
│ └────────────────────────────────┘ │    readable at a glance
│                                    │
│ ┌─────────┐┌─────────┐┌─────────┐  │
│ │HIT RATE ││ STREAK  ││ AVG     │  │  ← the goal user's real
│ │ 24/30   ││ 6 days  ││ 31 pg   │  │    question is "how often
│ └─────────┘└─────────┘└─────────┘  │    do I make it?"
│                                    │
│ HISTORY              ‹  July  ›    │
│ ┌────────────────────────────────┐ │
│ │  ●  ●  ◍  ●  ✕  ●  ●           │ │  ← day cell = met (●),
│ │  ●  ✕  ●  ●  ●  ◍  ◌           │ │    partial (◍ mini-ring),
│ └────────────────────────────────┘ │    missed (✕), future (◌)
└────────────────────────────────────┘
```

For a goal metric, **the hero slot shows today's progress ring instead of a
number+delta**, and the calendar day cells become mini goal-rings rather than
intensity squares. Everything else is inherited unchanged. The `goal`
TrackerKind from the creation flow gets its ring for free the moment
`NumberConfig.goal` is set — no special-casing at the navigation layer.

### Snapshot number ("Weight")

```
┌────────────────────────────────────┐
│ ‹ Back          Weight ⚖️      [⋯] │
├────────────────────────────────────┤
│                                    │
│  76.4 kg     ╭──────────────╮      │
│  Jul 7 ·     │ ▼ 0.8 kg /1M │      │  ← delta = change over the
│  Latest      ╰──────────────╯      │    range, neutral color —
│                                    │    down isn't always "good"
│ [  1M  │  6M  │  1Y  ]             │
│ ┌────────────────────────────────┐ │
│ │           ┌─────────┐          │ │
│ │           │ 77.1 kg │          │ │
│ │           │ Jun 12  │          │ │
│ │  ●╲       └────┬────┘          │ │  ← LINE, not bars. Bars
│ │    ●──●        ●               │ │    encode "amount produced";
│ │         ●──●─╱  ╲●──●          │ │    a snapshot is a level.
│ │ ── ── ── ── ── ── ── ──        │ │    Y-axis visible & zoomed
│ │ 74 ─────────────────── 78      │ │    to the data band (a 0-
│ └────────────────────────────────┘ │    based axis flattens it)
│                                    │
│ ┌─────────┐┌─────────┐┌─────────┐  │
│ │ AVG     ││ LOWEST  ││ HIGHEST │  │  ← range, not totals —
│ │ 76.9 kg ││ 75.8    ││ 78.2    │  │    summing weights is
│ └─────────┘└─────────┘└─────────┘  │    meaningless
│                                    │
│ HISTORY              ‹  July  ›    │
│ ┌────────────────────────────────┐ │
│ │  ●  ·  ●  ·  ·  ●  ·           │ │  ← logged/not-logged dots
│ │  ●  ·  ·  ●  ·  ·  ◌           │ │    only. Intensity shading
│ └────────────────────────────────┘ │    would imply "more =
└────────────────────────────────────┘    better" — wrong here
```

Snapshot-specific calls:

- **Line chart, not bars.** Bars visually say "this much was accumulated in
  this bucket"; a weight or heart-rate reading is a *level*, and levels read
  as lines (Apple Health's split: steps = bars, weight = line).
  `MetricBehavior` already tells which — `.cumulative` → `BarMark`,
  `.snapshot` → `LineMark` + `PointMark`.
- **Zoomed Y-axis.** Show the Y-axis for snapshot data and clamp the domain to
  the data band, otherwise a 75→78 kg journey renders as a flat line.
- **The intensity heatmap applies only to cumulative metrics.** For snapshots
  the calendar degrades to logged/not-logged — "darker = higher weight" would
  be a value judgment the UI shouldn't make.

## Where the branching lives

Three small factory-ish decisions instead of new screens:

```
heroStyle:   goal != nil → .gauge
             snapshot    → .latestWithTrend
             cumulative  → .totalWithDelta
chartStyle:  snapshot → .line   cumulative → .bars(goalLine: goal)
statsTiles:  goal → [hitRate, streak, avg]
             snapshot → [avg, min, max]
             cumulative → [total, avgPerDay, best]
```

Roughly three enums and a switch — versus N screens that drift apart the
first time one of them is touched.

## Implementation notes

- **Impact-per-effort order:** (1) pinned Log-entry pill and stats strip —
  additive, don't touch the calendar/chart plumbing, address the two biggest
  gaps (logging friction, no insight layer); (2) hero slot system
  (gauge / latestWithTrend / totalWithDelta); (3) in-chart selection callout
  + toggle removal — a bigger refactor, best done together.
- **Derived state:** when touching this, replace the six imperative
  `recompute*()` methods + `onAppear`/`onChange(of: data.count)` with computed
  properties or a small derived-state struct keyed on `(metric.data, range)`.
  The current pattern misses in-place edits (count unchanged) and every new
  section adds two more manual recompute call sites.
