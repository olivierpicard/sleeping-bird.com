//
//  MetricStatCalculatorTests.swift
//  ArperBirdTests
//

import Testing
import Foundation
@testable import ArperBird

@Suite("MetricStatCalculator")
@MainActor
struct MetricStatCalculatorTests {

    // MARK: - Helpers

    private static let calendar = Calendar.current

    /// Fixed "today" so every case reads as a concrete date rather than an
    /// offset from whenever the suite happens to run. Monday 10 Aug 2026 —
    /// the worked example in the decision doc.
    private static let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 10; c.hour = 9
        return calendar.date(from: c)!
    }()

    /// `daysAgo: 0` is today, `1` yesterday, and so on. Midday, so a point
    /// never lands on a day boundary by accident.
    private static func day(_ daysAgo: Int, hour: Int = 12) -> Date {
        let start = calendar.startOfDay(for: now)
        let shifted = calendar.date(byAdding: .day, value: -daysAgo, to: start)!
        return calendar.date(byAdding: .hour, value: hour, to: shifted)!
    }

    private static func stat(_ metric: Metric) -> MetricStatKind? {
        MetricStatCalculator.stat(for: metric, now: now, calendar: calendar)
    }

    /// A cumulative `sum` number metric — the only shape the percent applies to.
    private static func cumulative(_ data: [DataPoint]) -> Metric {
        Metric(
            from: .Fake.number(
                goal: nil,
                behavior: .cumulative,
                method: .numerical(.sum)
            ),
            data: data
        )
    }

    /// One numeric point per day, `values[0]` being `daysAgo: 1`.
    private static func dailyPoints(_ values: [Double], from daysAgo: Int = 1)
        -> [DataPoint]
    {
        values.enumerated().map { .number(day(daysAgo + $0.offset), $0.element) }
    }

    // MARK: - Nothing to say

    @Test("A metric with no data shows no badge")
    func emptyDataShowsNothing() {
        #expect(Self.stat(Self.cumulative([])) == nil)
    }

    @Test("Category and datetime metrics never badge")
    func categoryAndDatetimeShowNothing() {
        let category = Metric(
            from: .Fake.categorySingle(),
            data: [.category(Self.day(0), ["Happy"])]
        )
        let datetime = Metric(
            from: .Fake.datetime(),
            data: [.datetime(Self.day(0))]
        )
        #expect(Self.stat(category) == nil)
        #expect(Self.stat(datetime) == nil)
    }

    @Test("Idle doesn't sneak a badge onto category or datetime")
    func idleDoesNotReachBlankTypes() {
        // An event tracker's long gaps are its normal rhythm — a gas fill-up
        // twelve days ago is not neglect.
        let gasFillUps = Metric(
            from: .Fake.datetime(),
            data: [.datetime(Self.day(12)), .datetime(Self.day(28))]
        )
        let mood = Metric(
            from: .Fake.categorySingle(),
            data: [.category(Self.day(12), ["Happy"])]
        )
        #expect(Self.stat(gasFillUps) == nil)
        #expect(Self.stat(mood) == nil)
    }

    // MARK: - Idle

    @Test("Three days without an entry reports idle")
    func idleAtThreeDays() {
        let metric = Self.cumulative([.number(Self.day(3), 100)])
        #expect(Self.stat(metric) == .missing(days: 3))
    }

    @Test("Two days quiet is not yet idle")
    func notIdleAtTwoDays() {
        let metric = Self.cumulative([.number(Self.day(2), 100)])
        #expect(Self.stat(metric) == nil)
    }

    @Test("Idle outranks a percent computed across the gap")
    func idleBeatsPercent() {
        // Fully logged for four weeks, then silent for four days. The recent
        // block is starved by the silence, so its percent is an artifact.
        var data = Self.dailyPoints(Array(repeating: 2.0, count: 24), from: 4)
        data.append(.number(Self.day(28), 2.0))
        #expect(Self.stat(Self.cumulative(data)) == .missing(days: 4))
    }

    // MARK: - Binary streaks

    @Test("Consecutive yes-days count as a streak")
    func binaryStreakCountsYesDays() {
        let metric = Metric(
            from: .Fake.binary(),
            data: [
                .binary(Self.day(0), true),
                .binary(Self.day(1), true),
                .binary(Self.day(2), true),
            ]
        )
        #expect(Self.stat(metric) == .streak(days: 3))
    }

    @Test("A day logged false breaks the streak")
    func binaryFalseBreaksStreak() {
        let metric = Metric(
            from: .Fake.binary(),
            data: [
                .binary(Self.day(0), true),
                .binary(Self.day(1), true),
                .binary(Self.day(2), false),
                .binary(Self.day(3), true),
            ]
        )
        #expect(Self.stat(metric) == .streak(days: 2))
    }

    @Test("A streak survives midnight before today is logged")
    func streakCountsBackFromYesterday() {
        // Nothing logged today yet. Without the yesterday fallback every
        // streak in the app would read as broken each morning.
        let metric = Metric(
            from: .Fake.binary(),
            data: [
                .binary(Self.day(1), true),
                .binary(Self.day(2), true),
            ]
        )
        #expect(Self.stat(metric) == .streak(days: 2))
    }

    @Test("No recent yes-day means no streak")
    func binaryNoStreakWithoutRecentYes() {
        // Two days back is already too old: the walk starts at yesterday and
        // stops immediately. Still short of the 3-day idle threshold.
        let metric = Metric(
            from: .Fake.binary(),
            data: [.binary(Self.day(2), true)]
        )
        #expect(Self.stat(metric) == nil)
    }

    // MARK: - Goal streaks

    @Test("Days reaching the goal form a streak")
    func goalStreakCountsDaysAtOrAboveGoal() {
        let metric = Metric(
            from: .Fake.number(goal: 10_000, behavior: .cumulative),
            data: [
                .number(Self.day(0), 12_000),
                .number(Self.day(1), 10_000),
                .number(Self.day(2), 4_000),
            ]
        )
        #expect(Self.stat(metric) == .streak(days: 2))
    }

    @Test("A day's entries are summed before checking the goal")
    func goalStreakSumsTheDay() {
        // Four glasses rather than one bottle is the same day's water.
        let metric = Metric(
            from: .Fake.number(goal: 2.0, behavior: .cumulative),
            data: [
                .number(Self.day(0, hour: 8), 0.5),
                .number(Self.day(0, hour: 12), 0.5),
                .number(Self.day(0, hour: 16), 0.5),
                .number(Self.day(0, hour: 20), 0.5),
            ]
        )
        #expect(Self.stat(metric) == .streak(days: 1))
    }

    @Test("A goal metric shows nothing rather than falling back to a percent")
    func brokenGoalStreakShowsNothing() {
        // Two weeks of data, so the percent branch would have fired — but a
        // goal card is about the chain, and this one is broken.
        var data = Self.dailyPoints(Array(repeating: 500.0, count: 20))
        data.append(.number(Self.day(0), 500))
        let metric = Metric(
            from: .Fake.number(goal: 10_000, behavior: .cumulative),
            data: data
        )
        #expect(Self.stat(metric) == nil)
    }

    // MARK: - Percent

    @Test("Last seven days against the seven before them")
    func percentComparesTheTwoBlocks() {
        // prior (days 14…8) = 12.0, last (days 7…1) = 18.0 → +50%
        let prior: [Double] = [2.0, 2.0, 1.5, 2.0, 1.0, 2.0, 1.5]
        let last: [Double] = [2.5, 2.5, 2.5, 3.0, 2.0, 3.0, 2.5]
        let data = Self.dailyPoints(last) + Self.dailyPoints(prior, from: 8)
        #expect(Self.stat(Self.cumulative(data)) == .increase(percent: 50))
    }

    @Test("Today is excluded, so a partial day can't drag the badge down")
    func todayIsExcludedFromBothBlocks() {
        let prior: [Double] = [2.0, 2.0, 1.5, 2.0, 1.0, 2.0, 1.5]
        let last: [Double] = [2.5, 2.5, 2.5, 3.0, 2.0, 3.0, 2.5]
        var data = Self.dailyPoints(last) + Self.dailyPoints(prior, from: 8)
        // A single sip logged so far today. The badge must not move.
        data.append(.number(Self.day(0), 0.1))
        #expect(Self.stat(Self.cumulative(data)) == .increase(percent: 50))
    }

    @Test("A drop reads as a decrease")
    func percentReportsDecrease() {
        let data =
            Self.dailyPoints(Array(repeating: 1.0, count: 7))
            + Self.dailyPoints(Array(repeating: 2.0, count: 7), from: 8)
        #expect(Self.stat(Self.cumulative(data)) == .decrease(percent: 50))
    }

    @Test("A flat tracker shows no badge")
    func flatTrackerShowsNothing() {
        let data = Self.dailyPoints(Array(repeating: 2.0, count: 14))
        #expect(Self.stat(Self.cumulative(data)) == nil)
    }

    @Test("Changes under five percent are dropped as noise")
    func belowNoiseFloorShowsNothing() {
        // prior 14.0, last 14.4 → +2.9%
        let data =
            Self.dailyPoints([2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.4])
            + Self.dailyPoints(Array(repeating: 2.0, count: 7), from: 8)
        #expect(Self.stat(Self.cumulative(data)) == nil)
    }

    // MARK: - Percent: what it refuses to compute

    @Test("A tracker younger than fourteen days shows no percent")
    func youngTrackerShowsNoPercent() {
        // Flat 2.0/day since day one. Comparing raw totals here would report a
        // large increase purely because the prior block predates the tracker.
        let data = Self.dailyPoints(Array(repeating: 2.0, count: 8))
        #expect(Self.stat(Self.cumulative(data)) == nil)
    }

    @Test("Fourteen days of backdated history is enough")
    func backdatedHistoryUnlocksThePercent() {
        // Same data as the +50% case, but it could all have been entered today —
        // the gate reads the oldest point, not `createdAt`.
        let prior: [Double] = [2.0, 2.0, 1.5, 2.0, 1.0, 2.0, 1.5]
        let last: [Double] = [2.5, 2.5, 2.5, 3.0, 2.0, 3.0, 2.5]
        let metric = Metric(
            from: .Fake.number(
                goal: nil,
                behavior: .cumulative,
                method: .numerical(.sum)
            ),
            data: Self.dailyPoints(last) + Self.dailyPoints(prior, from: 8),
            createdAt: Self.now
        )
        #expect(Self.stat(metric) == .increase(percent: 50))
    }

    @Test("Snapshot metrics have no percent branch")
    func snapshotShowsNoPercent() {
        let metric = Metric(
            from: .Fake.number(
                goal: nil,
                behavior: .snapshot,
                method: .numerical(.sum)
            ),
            data: Self.dailyPoints(Array(repeating: 2.0, count: 7))
                + Self.dailyPoints(Array(repeating: 1.0, count: 7), from: 8)
        )
        #expect(Self.stat(metric) == nil)
    }

    @Test("Only the sum method reaches the percent")
    func nonSumMethodShowsNoPercent() {
        for method: NumericMethod in [.average, .min, .max, .latest] {
            let metric = Metric(
                from: .Fake.number(
                    goal: nil,
                    behavior: .cumulative,
                    method: .numerical(method)
                ),
                data: Self.dailyPoints(Array(repeating: 2.0, count: 7))
                    + Self.dailyPoints(Array(repeating: 1.0, count: 7), from: 8)
            )
            #expect(Self.stat(metric) == nil, "\(method) should not badge")
        }
    }

    @Test("An empty prior block never divides by zero")
    func zeroPriorBlockShowsNothing() {
        // Oldest point is old enough to pass the gate, but the prior block
        // itself holds nothing.
        var data = Self.dailyPoints(Array(repeating: 2.0, count: 7))
        data.append(.number(Self.day(30), 2.0))
        #expect(Self.stat(Self.cumulative(data)) == nil)
    }

    // MARK: - Duration

    @Test("Cumulative duration metrics badge like numbers")
    func cumulativeDurationGetsAPercent() {
        let last = Array(repeating: 1_800.0, count: 7)
        let prior = Array(repeating: 1_200.0, count: 7)
        let metric = Metric(
            from: .Fake.duration(
                method: .numerical(.sum),
                behavior: .cumulative
            ),
            data: last.enumerated().map {
                .duration(Self.day(1 + $0.offset), $0.element)
            }
                + prior.enumerated().map {
                    .duration(Self.day(8 + $0.offset), $0.element)
                }
        )
        #expect(Self.stat(metric) == .increase(percent: 50))
    }
}
