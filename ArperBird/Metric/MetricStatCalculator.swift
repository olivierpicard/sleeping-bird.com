//
//  MetricStatCalculator.swift
//  ArperBird
//
//  Created by Olivier Picard on 10/08/2026.
//

import Foundation

/// The four glanceable states a metric's trend badge can show. Each case
/// carries its own raw number — `MetricStatBadge` composes and localizes the
/// text itself, so callers never build display strings by hand.
enum MetricStatKind: Equatable {
    case increase(percent: Int)
    case decrease(percent: Int)
    case streak(days: Int)
    case missing(days: Int)
}

/// Derives a card's trend badge from its data. Stateless and pure — no
/// SwiftData, no views, and `now` is injected so streaks and idle are testable
/// without freezing the clock.
///
/// The full reasoning, including everything deliberately left out, is in
/// `docs/decisions/0013-metric-stat-badge.md`.
enum MetricStatCalculator {

    // MARK: - Tunables

    /// Days without an entry before the card reports the tracker as idle.
    private static let idleDayThreshold = 3

    /// Length of each comparison block. Two of these sit back to back, so the
    /// percent also needs twice this much history before it will show at all.
    private static let blockDays = 7

    /// Changes smaller than this read as noise — the "stable" state is dropped,
    /// not drawn. Everything reaching the percent branch is cumulative, so one
    /// floor covers all of it.
    private static let noiseFloorPercent = 5

    // MARK: - Entry point

    /// The badge for this metric, or `nil` when it has nothing worth saying.
    ///
    /// Resolution is first-match-wins, and idle deliberately outranks the rest:
    /// a percent computed across a logging gap is measuring the gap.
    static func stat(
        for metric: Metric,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MetricStatKind? {
        guard !metric.data.isEmpty, canBadge(metric.config) else { return nil }

        if let idle = idleStat(for: metric, now: now, calendar: calendar) {
            return idle
        }

        switch metric.config {
        case .binary:
            return binaryStreak(for: metric, now: now, calendar: calendar)

        case .number(let cfg):
            // A goal card's chart already draws progress toward today's target,
            // which makes a week-over-week percent the odd fact out. The chain
            // is what the user is actually watching.
            if let goal = cfg.goal, goal > 0 {
                return goalStreak(
                    for: metric,
                    goal: goal,
                    now: now,
                    calendar: calendar
                )
            }
            return percentChange(
                for: metric,
                behavior: cfg.behavior,
                now: now,
                calendar: calendar
            )

        case .duration(let cfg):
            return percentChange(
                for: metric,
                behavior: cfg.behavior,
                now: now,
                calendar: calendar
            )

        case .categorySingleChoice, .categoryMultipleChoice, .datetime:
            return nil  // Already refused by `canBadge`.
        }
    }

    /// Whether this kind of tracker carries a badge at all.
    ///
    /// A percent over category labels means nothing, and for an event tracker
    /// the long gaps *are* the data — a gas fill-up four days ago is a normal
    /// fortnightly rhythm, not neglect, so even idle would be a false alarm.
    /// Checked before idle so those two never badge by that route either.
    private static func canBadge(_ config: MetricConfig) -> Bool {
        switch config {
        case .binary, .number, .duration:
            return true
        case .categorySingleChoice, .categoryMultipleChoice, .datetime:
            return false
        }
    }

    // MARK: - Idle

    private static func idleStat(
        for metric: Metric,
        now: Date,
        calendar: Calendar
    ) -> MetricStatKind? {
        guard let newest = metric.data.map(\.date).max() else { return nil }
        let days =
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: newest),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
        guard days >= idleDayThreshold else { return nil }
        return .missing(days: days)
    }

    // MARK: - Streaks

    private static func binaryStreak(
        for metric: Metric,
        now: Date,
        calendar: Calendar
    ) -> MetricStatKind? {
        // Only "yes" days count, so a day logged `false` breaks the chain
        // rather than extending it.
        var yesDays: Set<Date> = []
        for point in metric.data {
            guard case .binary(let date, let flag) = point, flag else { continue }
            yesDays.insert(calendar.startOfDay(for: date))
        }
        return streak(over: yesDays, now: now, calendar: calendar)
    }

    private static func goalStreak(
        for metric: Metric,
        goal: Double,
        now: Date,
        calendar: Calendar
    ) -> MetricStatKind? {
        let hitDays = dailyTotals(of: metric, calendar: calendar)
            .filter { $0.value >= goal }
            .keys
        return streak(over: Set(hitDays), now: now, calendar: calendar)
    }

    /// Walks back a day at a time from today — or from yesterday when today
    /// hasn't qualified yet. Without that fallback every streak in the app
    /// would look broken from midnight until the day's entry lands.
    ///
    /// Any day that doesn't qualify ends the count, an unlogged one included.
    ///
    /// A single qualifying day doesn't read as a "streak," so it's swallowed
    /// rather than badged — two days back to back is the floor.
    private static func streak(
        over qualifyingDays: Set<Date>,
        now: Date,
        calendar: Calendar
    ) -> MetricStatKind? {
        let today = calendar.startOfDay(for: now)
        var cursor =
            qualifyingDays.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var count = 0
        while qualifyingDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor)
            else { break }
            cursor = previous
        }

        guard count >= 2 else { return nil }
        return .streak(days: count)
    }

    // MARK: - Percent change

    /// Last seven whole days against the seven before them.
    ///
    /// Restricted to cumulative `sum` metrics. Every other aggregation distorts
    /// differently — `average` follows logging habits, `min`/`max` let one
    /// extreme day define a block, `latest` rests each side on a single day —
    /// and percent change is meaningless on the arbitrary-zero scales that
    /// snapshot metrics tend to use (2°C to 4°C is not "+100%" of anything).
    private static func percentChange(
        for metric: Metric,
        behavior: MetricBehavior,
        now: Date,
        calendar: Calendar
    ) -> MetricStatKind? {
        guard behavior == .cumulative,
            case .numerical(.sum) = metric.visual.aggregation.method
        else { return nil }

        let totals = dailyTotals(of: metric, calendar: calendar)
        let today = calendar.startOfDay(for: now)

        guard
            let priorStart = calendar.date(
                byAdding: .day,
                value: -2 * blockDays,
                to: today
            ),
            let lastStart = calendar.date(
                byAdding: .day,
                value: -blockDays,
                to: today
            )
        else { return nil }

        // Both blocks have to sit inside the tracker's own history. Otherwise
        // the prior one reaches back before any data existed and a perfectly
        // flat tracker reports a huge increase for its first two weeks.
        // Measured from the oldest point, not `createdAt`, because entries can
        // be backdated — someone importing a month of history has 14 days to
        // compare on day one.
        guard let oldest = totals.keys.min(), oldest <= priorStart else {
            return nil
        }

        // Today is in neither block: a partial day would dilute the recent one
        // by up to a seventh, so cards would sag every morning and recover
        // every evening on nothing but the clock.
        let prior = sum(of: totals, from: priorStart, upTo: lastStart)
        let last = sum(of: totals, from: lastStart, upTo: today)

        guard prior != 0 else { return nil }

        let percent = Int(((last - prior) / abs(prior) * 100).rounded())
        guard abs(percent) >= noiseFloorPercent else { return nil }
        return percent > 0
            ? .increase(percent: percent)
            : .decrease(percent: abs(percent))
    }

    // MARK: - Shared

    /// Every day holding at least one numeric point, keyed by its start of day,
    /// with that day's values summed. Both the goal streak and the percent read
    /// *days* rather than raw entries, so logging one bottle or four glasses
    /// comes to the same thing.
    private static func dailyTotals(
        of metric: Metric,
        calendar: Calendar
    ) -> [Date: Double] {
        var totals: [Date: Double] = [:]
        for point in metric.data {
            let value: Double
            switch point {
            case .number(_, let v): value = v
            case .duration(_, let interval): value = interval
            default: continue
            }
            totals[calendar.startOfDay(for: point.date), default: 0] += value
        }
        return totals
    }

    private static func sum(
        of totals: [Date: Double],
        from start: Date,
        upTo end: Date
    ) -> Double {
        totals.reduce(into: 0.0) { running, entry in
            guard entry.key >= start, entry.key < end else { return }
            running += entry.value
        }
    }
}
