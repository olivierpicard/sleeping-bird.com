# 0014 — Category trackers get an idle badge, no streak

- **Date:** 2026-08-10
- **Status:** Accepted
- **Area:** `MetricStatCalculator`
- **Supersedes:** part of [0013](0013-metric-stat-badge.md) decision 7 — the category half only. Date trackers stay excluded, unchanged.

## Context

Decision 7 of [0013](0013-metric-stat-badge.md) grouped category trackers with date
trackers and gave both no badge at all, idle included — but said outright that
category's case "isn't as clear-cut" as date's. The reasoning that actually holds
for category is narrower than what got applied to it:

- **A percent over category labels is meaningless.** Mood logged as "Happy" vs.
  "Sad" has no numeric direction — this still holds, and category still never
  reaches the percent branch.
- **The "long gaps are the data" argument was about date**, not category — a gas
  fill-up every two weeks is a normal rhythm for an *event* tracker. Most category
  trackers (mood, symptoms, energy level) are meant to be logged roughly daily, so
  a multi-day gap is closer to "forgot to check in" than "nothing happened."

A first pass also gave category a **streak** — reusing `binaryStreak`'s machinery,
with any logged choice counting as a qualifying day. That doesn't survive scrutiny:
a streak of "logged *something*", indifferent to which choice, measures app usage
rather than the thing being tracked — the exact problem 0013 decision 7 used to
disqualify a date streak ("a streak of 'recorded a date' measures app usage rather
than the thing being tracked"). Binary's streak and the goal streak both track a
real fact about the metric (consecutive `true` days, days at or above a target);
a generic category streak doesn't have an equivalent to point to.

## Decision

Category configs (`categorySingleChoice`, `categoryMultipleChoice`) now pass
`canBadge` and reach **idle**, using the same 3-day threshold as every other
badged config — `idleStat` only looks at "days since the newest point" and
doesn't know or care about `config`. They still never reach a streak or a
percent; the `switch` in `stat(for:)` returns `nil` for all three category/date
branches once idle has had its chance.

`.datetime` is unchanged and still excluded entirely, per 0013 decision 7 — an
event tracker's gaps are still its normal rhythm, so even idle would be a false
alarm there.

*Rejected: a logging streak on "any choice counts."* Superseded by the reasoning
above — it would just be a second, badge-shaped way of saying "app usage,"
which decision 7 already ruled out for date.

*Rejected: a streak on a specific choice* (e.g. the most logged label, or a
notion of a "target" choice). Categories have no goal-like field today, so this
would need new schema and creation-flow UI to let a user pick a target — a bigger
change than this decision is scoped to. Worth revisiting if a real tracker asks
for it.

## Consequences

- `MetricStatCalculator.canBadge` now only excludes `.datetime`; category configs
  pass it but only to reach idle, same as `average`/`min`/`max`/`latest` number
  metrics already do.
- No new streak function — `dailyTotals`, `streak(over:now:calendar:)`, and every
  other helper are untouched.
- Test coverage in `ArperBirdTests/MetricStatCalculatorTests.swift`: category
  metrics go idle at 3 days, and stay badge-less however many consecutive days
  they're logged.
