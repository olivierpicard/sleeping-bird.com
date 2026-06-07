//
//  MetricAggregatorTests.swift
//  ArperBirdTests
//

import Testing
import Foundation
@testable import ArperBird

@Suite("MetricAggregator")
@MainActor
struct MetricAggregatorTests {

    // MARK: - Helpers

    private static let calendar = Calendar.current

    private static func day(_ year: Int, _ month: Int, _ d: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = d; c.hour = hour
        return calendar.date(from: c)!
    }

    private static func bins(
        _ points: [DataPoint],
        range: TimeRange = .month,
        method: NumericMethod = .sum,
        behavior: MetricBehavior = .snapshot
    ) -> [ChartBin] {
        MetricAggregator.bins(from: points, range: range, method: method, behavior: behavior)
    }

    // MARK: - Bucketing by TimeRange

    @Test("Same-day points collapse into one daily bucket for .week")
    func groupsSameDayForWeek() {
        let morning = Self.day(2026, 1, 5, hour: 8)
        let evening = Self.day(2026, 1, 5, hour: 21)
        let result = Self.bins([.number(morning, 10), .number(evening, 20)])

        #expect(result.count == 1)
        #expect(result.first?.value == 30)
        #expect(result.first?.count == 2)
    }

    @Test("Points in the same week collapse for .sixMonths")
    func groupsByWeekForSixMonths() {
        let monday = Self.day(2026, 1, 5)
        let wednesday = Self.day(2026, 1, 7)
        let nextWeek = Self.day(2026, 1, 14)

        let result = Self.bins(
            [.number(monday, 1), .number(wednesday, 2), .number(nextWeek, 5)],
            range: .sixMonths
        )

        #expect(result.count == 2)
        #expect(result[0].value == 3)
        #expect(result[1].value == 5)
    }

    @Test("Points in the same month collapse for .year")
    func groupsByMonthForYear() {
        let result = Self.bins(
            [
                .number(Self.day(2026, 1, 5), 1),
                .number(Self.day(2026, 1, 28), 2),
                .number(Self.day(2026, 3, 1), 9),
            ],
            range: .year
        )

        #expect(result.count == 2)
        #expect(result[0].value == 3)
        #expect(result[1].value == 9)
    }

    // MARK: - Aggregation methods

    @Test("sum totals every value in the bucket")
    func sumMethod() {
        let result = Self.bins(sameDayValues([10, 20, 30]), method: .sum)
        #expect(result.first?.value == 60)
    }

    @Test("average divides total by count")
    func averageMethod() {
        let result = Self.bins(sameDayValues([10, 20, 30]), method: .average)
        #expect(result.first?.value == 20)
    }

    @Test("min picks the smallest value")
    func minMethod() {
        let result = Self.bins(sameDayValues([10, 20, 30]), method: .min)
        #expect(result.first?.value == 10)
    }

    @Test("max picks the largest value")
    func maxMethod() {
        let result = Self.bins(sameDayValues([10, 20, 30]), method: .max)
        #expect(result.first?.value == 30)
    }

    @Test("latest picks the most recent point's value")
    func latestMethod() {
        let points: [DataPoint] = [
            .number(Self.day(2026, 1, 5, hour: 1), 1),
            .number(Self.day(2026, 1, 5, hour: 9), 99),
            .number(Self.day(2026, 1, 5, hour: 5), 50),
        ]
        let result = Self.bins(points, method: .latest)
        #expect(result.first?.value == 99)
    }

    private func sameDayValues(_ values: [Double]) -> [DataPoint] {
        values.enumerated().map { i, v in
            .number(Self.day(2026, 1, 5, hour: i + 1), v)
        }
    }

    // MARK: - Cumulative gap-filling

    @Test("Cumulative behavior fills missing days with zero-valued bins")
    func cumulativeFillsGaps() {
        let result = Self.bins(
            [.number(Self.day(2026, 1, 1), 5), .number(Self.day(2026, 1, 4), 7)],
            behavior: .cumulative
        )

        #expect(result.count == 4)
        #expect(result[0].value == 5)
        #expect(result[1].value == 0)
        #expect(result[1].count == 0)
        #expect(result[2].value == 0)
        #expect(result[3].value == 7)
    }

    @Test("Snapshot behavior leaves gaps out")
    func snapshotKeepsGaps() {
        let result = Self.bins(
            [.number(Self.day(2026, 1, 1), 5), .number(Self.day(2026, 1, 4), 7)],
            behavior: .snapshot
        )
        #expect(result.count == 2)
    }

    // MARK: - Sort order

    @Test("Bins are returned sorted ascending by date regardless of input order")
    func sortedAscending() {
        let result = Self.bins(
            [
                .number(Self.day(2026, 3, 1), 1),
                .number(Self.day(2026, 1, 5), 2),
                .number(Self.day(2026, 2, 10), 3),
            ],
            range: .year
        )
        let dates = result.map(\.date)
        #expect(dates == dates.sorted())
    }

    // MARK: - Empty / unsupported input

    @Test("Empty input returns no bins")
    func emptyInput() {
        #expect(Self.bins([]).isEmpty)
    }

    @Test("Non-numeric DataPoints are ignored")
    func ignoresNonNumeric() {
        let d = Self.day(2026, 1, 5)
        let result = Self.bins([
            .binary(d, true),
            .category(d, ["A"]),
            .datetime(d),
        ])
        #expect(result.isEmpty)
    }

    // MARK: - Mixed numeric sources

    @Test(".number and .duration are aggregated together")
    func mixesNumberAndDuration() {
        let result = Self.bins([
            .number(Self.day(2026, 1, 5, hour: 1), 100),
            .duration(Self.day(2026, 1, 5, hour: 2), 200),
        ])

        #expect(result.count == 1)
        #expect(result.first?.value == 300)
    }
}
