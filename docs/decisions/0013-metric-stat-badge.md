# 0013 — Metric stat badge: what it says and how it's derived

- **Date:** 2026-08-10
- **Status:** Accepted
- **Area:** Metric card header (`MetricStatBadge`, `MetricHeaderValueView`, `MetricViewFactory`, and a new `MetricStatCalculator`)

![The four badge states on dashboard cards](assets/0013-stat-badges.png)

## Context

`MetricStatBadge` shipped as a static mockup: the view and its four cases
(`increase`, `decrease`, `streak`, `missing`) exist, `MockStatHeader` positions
it under the card's value, but nothing computes which case a real tracker should
show. This decision fills that gap.

The card already carries two facts: a headline value (windowed to the metric's
aggregation bucket, so usually *today*) and a mini chart. The badge has to add a
third that neither of those gives — **how the tracker has been behaving lately** —
without competing with them.

Three constraints shaped everything below:

- **No good/bad valence.** `+50%` is a win on steps and a loss on coffee, and the
  schema doesn't know which. The badge is drawn in the tracker's own color and the
  states are told apart by icon shape, never by red/green.
- **The badge must not go stale.** A trend that survives adding an entry is worse
  than no trend at all.
- **One pure function.** Everything derivable from `metric.data` + `config` +
  `visual`, with no stored state to migrate and no network.

## Decisions

### 1. The percent is only for cumulative `sum` metrics

Water, steps, calories, screen time. Everything else shows no percent: all
snapshot metrics, and any cumulative metric aggregated by `average`, `min`, `max`,
or `latest`.

Each excluded method carries a different distortion, and each would need its own
correction:

| method | what goes wrong |
| --- | --- |
| `average` | a day logged 5× outweighs a day logged once — the block average follows logging habits, not the metric |
| `min` / `max` | one extreme day defines the whole block, so the percent lurches |
| `latest` | each side of the comparison rests on a single day |

There is also a scale problem that only bites outside `sum`: percent change is
meaningless on a scale with an arbitrary zero. `2°C → 4°C` is not "+100%" of
anything. Temperature, a mood score of −5…+5, an account balance — all snapshot,
all excluded here, so no guard is needed for them.

*Rejected: support every method with a per-method correction.* Collapsing each day
to a single value first would genuinely fix `average`, and a `NumberConfig.min < 0`
check would catch the arbitrary-zero scales. But that's three rules and two guards
to make four rarely-used aggregations behave, when `sum` covers the metrics people
actually want a weekly trend on. Excluded methods can be added back one at a time
if a real tracker needs one.

Consequence worth naming: a weight tracker now shows **no badge at all** unless it
goes idle. That's accepted — see decision 8 for why it was nearly badge-less
anyway.

### 2. A rolling 7 days against the 7 before it

*Rejected: current bucket vs previous bucket* (daily → today vs yesterday). Most
literal, but it makes the badge jump on every single entry — a number that changes
that often stops being glanceable.

*Rejected: window sized from the metric's bucket* (daily → 7d, weekly → 4w,
monthly → 3m). More correct for slow trackers, but the badge would silently mean a
different period on each card, and nothing on the card says which.

*Rejected: calendar weeks.* Mid-week you'd compare a partial week against a full
one, so every card would read negative on Monday and climb until Sunday.

The rolling window always puts seven whole days against seven whole days, so the
only thing that can move it is the data.

### 3. Today is excluded from both blocks

A partial day dilutes a block by up to a seventh — well past the 5% noise floor.
Without this, cards would sag every morning and recover every evening on nothing
but the clock. The headline value already covers today; the badge is the trend
*behind* it.

### 4. No percent until the tracker has 14 days of history

Both blocks span days −14 … −1, so a tracker younger than that has a prior block
reaching back before it existed. Comparing totals across it produces a fake spike.
Take a tracker created on day 1 logging **exactly 2.0 L every single day** —
perfectly flat, the badge should say nothing:

```
DAY 9
  prior block = days -5 … 1   → only day 1 exists yet  →   2.0 L
  last block  = days  2 … 8   → seven full days        →  14.0 L
  (14.0 − 2.0) / 2.0                                   =  ▲ +600%
```

Every new tracker would do this from day 9 to day 14, guaranteed. Requiring 14 days
of history means both blocks are always full weeks, which is also the only point
where the comparison is like-for-like: **identical weekday composition on both
sides**. Water and steps have a strong weekly rhythm, so a partial baseline of, say,
Mon–Wed against a full week including a weekend is a systematic bias, not noise.

*Rejected: normalize each block to a daily rate* (`sum ÷ days covered`), which also
removes the spike and would show a first badge on day 9. It buys six days at the
cost of a baseline that can rest on one or two unrepresentative days — and the
weekday bias survives it. Gating on history is both simpler and stricter.

With this gate the arithmetic stays plain totals: both blocks divide by the same 7,
so the division cancels. The multi-entry-day problem — four glasses versus one
bottle — was only ever an `average` problem; `sum` is blind to entry count.

**Age is measured from the oldest data point, not `metric.createdAt`.** Entries can
be backdated ([0009](0009-backdated-entries.md)), so the two diverge: someone who
enters a month of past history has 14 days to compare on day one, while a tracker
that sat empty for three weeks has nothing. The gate is about having the data, not
about the tracker's age.

### 5. Goal metrics show a streak instead of a percent

On a gauge card the chart already draws progress toward today's goal, which makes
"12% more than last week" the odd fact out. What the user wants to know is whether
the chain is alive.

The first framing considered was goal streaks *alongside* the percent — rejected,
because that was the only thing that would have made two badges co-occur, and it
forced an `HStack` plus wrapping work to show a second fact nobody asked for.

### 6. A goal is always a floor. No `goalDirection` field

`NumberConfig.goal` and `GoalAiCompletionSchema.dailyGoal` are bare numbers —
nothing records whether a target is a floor ("drink 2.5 L") or a ceiling ("stay
under 3 coffees"). Read as a floor, a limit tracker congratulates the user with
`⚡ 4d streak` for exceeding the thing they're limiting.

*Rejected: add an optional `goalDirection` to `NumberConfig`.* The additive-only
shape would have been safe for the migration plan, but the premise is wrong: a
progress bar that **fills up** as you drink coffee is already the wrong picture for
"stay under 3". A ceiling isn't a goal in this app — it's a plain number tracker.
The gauge is the goal's UI, and the gauge only means "accumulate toward a target".

Consequence: if the AI ever resolves a limit-shaped intent to the goal kind, that's
a **tracker-creation** bug to fix there, not something the badge should paper over.

### 7. Date and category trackers get no badge — idle included

A percent over category labels is meaningless. Date trackers could carry a logging
streak, but a streak of "recorded a date" measures app usage rather than the thing
being tracked. Both stay blank; their charts already say what there is to say.

**Blank means blank, so the type check runs before idle.** A gas fill-up tracker
logs roughly twice a month, so a fixed 3-day idle threshold would flag a perfectly
normal gap as neglect within days of every fill-up. For an event tracker the long
gaps *are* the data. Category trackers are grouped with it for consistency rather
than because their case is as clear-cut.

### 8. The noise floor is a flat 5%

Changes under 5% show no badge — the "stable" state is dropped, not drawn.

An earlier draft split the floor by behavior (5% cumulative, 1% snapshot) because a
flat 5% would have deleted the badge on slow-moving trackers: **5% of 73 kg is
3.6 kg in a week**, so a weight card would essentially never qualify. Decision 1
made that split moot — snapshot metrics no longer reach the percent branch at all,
so everything the floor applies to is cumulative and 5% is the right number for all
of it.

### 9. One badge per card, never two

With the rules above, the collisions are:

| pair | possible? | why |
| --- | --- | --- |
| streak + percent | no | streak is binary-or-goal, percent is cumulative-sum — disjoint |
| streak + idle | no | 3 days quiet means the streak already broke |
| idle + percent | **yes** | the only real one |

And in that one case the percent is an artifact of the silence, not a second fact:

```
💧 Water — 2.5 L/day for three weeks, then logging stops four days ago
   last 7d:   7.5 L
   prior 7d: 17.5 L                        → -57%

   🌙 4d idle   ▼ -57%      ← the same fact twice
```

So `stat(for:)` returns a single optional, not an array. *Rejected: plural
signature "ready for later"* — it would hold exactly one element in every case that
exists today, which is the definition of a speculative hook. Goal streaks on
non-goal numbers, or a "new record" state, are what would earn the array.

### 10. Idle outranks everything

Falling quiet is the more useful thing to surface, and any percent computed across
a gap is measuring the gap.

### 11. The percent shows bare — `+50%`, no period

Known weakness, accepted for now. The streak and idle badges name their own window
("3d streak", "3d idle") and so can't be misread. The percent doesn't, and it sits
directly under a value on a *different* timescale — the value is today, the percent
is two weeks of history:

```
💧 Water
1.8 L        ← today
▲ +50%       ← last 7 days vs the 7 before
```

Read together, that invites "I drank 50% more today", which is not what it says.
*Deferred: `+50% vs last week`* — clearest, but a wider pill that needs wrapping
work at accessibility text sizes. Revisit if the misreading shows up in use.

## Resulting business logic

`MetricStatCalculator.stat(for:now:) -> MetricStatKind?` — pure, no SwiftData, no
views, with `now` injected so streaks and idle are testable without freezing the
clock.

**Resolution order.** First match wins:

```
data empty ──────────────────────────► nil
category · datetime ─────────────────► nil     ← before idle, so it can't badge them
last entry ≥ 3 days old ─────────────► 🌙 .missing(days:)
binary ──────────────────────────────► ⚡ .streak   yes-days
number WITH a goal > 0 ──────────────► ⚡ .streak   days at or above goal
cumulative + sum, no goal ───────────► ▲▼ percent  7d vs prior 7d
everything else ─────────────────────► nil
```

That last line covers snapshot metrics and `average`/`min`/`max`/`latest` — types
that can badge in principle but have no percent to show. They still reach idle.

**Idle.** Whole days between the newest entry's day and today. `≥ 3` → `.missing`.

**Streaks.** Count back from today if today qualifies, otherwise from yesterday —
without that, every streak in the app breaks at midnight and heals on the next
entry. Any day that doesn't qualify ends the count, including an unlogged one.
Zero → no badge (a goal card that broke its streak shows nothing; it does not fall
back to a percent).

- *binary:* a day qualifies if it holds at least one `true`. A day logged only
  `false` breaks the streak.
- *goal:* a day qualifies if the **sum** of that day's values is `>= goal`.

**Percent.** Requires the **oldest data point** to be at least 14 days old (not
`createdAt` — entries can be backdated). Then:

1. Cut two blocks of whole days, today in neither:
   `last = [-7 … -1]`, `prior = [-14 … -8]`.
2. Sum each block.
3. `(last - prior) / prior × 100`, rounded to an `Int`. Under 5% → no badge.

Worked, with today = Mon Aug 10:

```
PRIOR 7 DAYS               LAST 7 DAYS                TODAY
Jul 27   1.5 L             Aug  3   2.5 L             Aug 10   1.8 L
Jul 28   2.0 L             Aug  4   3.0 L
Jul 29   1.0 L             Aug  5   2.0 L             ignored —
Jul 30   2.0 L             Aug  6   3.0 L             the day
Jul 31   1.5 L             Aug  7   2.5 L             isn't over
Aug  1   2.0 L             Aug  8   2.5 L
Aug  2   2.0 L             Aug  9   2.5 L
        ──────                     ──────
prior =   12.0 L           last =    18.0 L

(18.0 − 12.0) / 12.0 = +0.50  →  ▲ +50%
```

Tomorrow both blocks slide one day and the badge reads `+33%`. Nothing changed but
which days are in frame.

**Guards.** `nil` — never a crash, never `+∞%` — when the tracker is younger than 14
days, when the prior block sums to `0`, or when the change is under 5%.

**Earliest appearance.** A tracker created on day 1 shows its first percent on
**day 15**.

## Consequences

- Weight, temperature, mood-score and other snapshot trackers show no badge unless
  they go idle. Their charts carry the trend instead.
- New cumulative trackers are badge-less for their first two weeks — the longest
  wait in the design, and the deliberate price of never showing a wrong number.
  Binary and goal cards get a streak almost immediately, and `🌙 idle` can fire on
  anything, so a dashboard is rarely entirely bare.
- Recomputed on every render, one filter pass over `metric.data`, no caching. The
  dashboard re-renders on SwiftData change, which is what keeps the badge honest
  after an entry is added.
- `MetricStatKind` moves out of `MetricStatBadge.swift` into the calculator, so the
  badge goes back to pure rendering and the domain owns the meaning.
- `MockStatHeader` in `MetricView.swift` is deleted; the mockup preview points at
  the real `MetricHeaderValueView`.
- The badge's period being unstated (decision 11) is the most likely thing to come
  back. A follow-up ADR supersedes this one if it does.
