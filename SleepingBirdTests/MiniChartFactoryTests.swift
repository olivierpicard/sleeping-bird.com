//
//  MiniChartFactoryTests.swift
//  SleepingBirdTests
//

import XCTest
import SwiftUI
@testable import SleepingBird

@MainActor
final class MiniChartFactoryTests: XCTestCase {

    private func metric(schema: MetricSchema, data: [DataPoint]) -> Metric {
        Metric(from: schema, data: data)
    }

    // MARK: - Empty data

    func test_emptyData_returnsNoDataMiniChart() {
        let m = metric(schema: .Fake.number(), data: [])
        XCTAssertTrue(MiniChartFactory.make(from: m) is NoDataMiniChart)
    }

    // MARK: - Number

    func test_number_line_returnsLineMiniChart_withCorrectData() {
        let data: [DataPoint] = [.number(Date(), 42), .number(Date(), 80)]
        let m = metric(schema: .Fake.number(goal: nil, chart: .line), data: data)
        let chart = MiniChartFactory.make(from: m) as? LineMiniChart
        XCTAssertNotNil(chart)
        XCTAssertEqual(chart?.data, [42, 80])
    }

    func test_number_bar_returnsBarMiniChart_withCorrectData() {
        let data: [DataPoint] = [.number(Date(), 10), .number(Date(), 20)]
        let m = metric(schema: .Fake.number(goal: nil, chart: .bar), data: data)
        let chart = MiniChartFactory.make(from: m) as? BarMiniChart
        XCTAssertNotNil(chart)
        XCTAssertEqual(chart?.data, [10, 20])
    }

    func test_number_gauge_returnsLinearGauge_withCurrentAndGoal() {
        let data: [DataPoint] = [.number(Date(), 60)]
        let m = metric(schema: .Fake.number(goal: 80, chart: .gauge), data: data)
        let chart = MiniChartFactory.make(from: m) as? LinearGaugeMiniChart
        XCTAssertNotNil(chart)
        XCTAssertEqual(chart?.current, 60)
        XCTAssertEqual(chart?.goal, 80)
    }

    // MARK: - Category

    func test_categorySingle_returnsDividerBar_withFrequencies() {
        let data: [DataPoint] = [
            .category(Date(), ["Happy"]),
            .category(Date(), ["Sad"]),
            .category(Date(), ["Happy"]),
        ]
        let m = metric(schema: .Fake.categorySingle(labels: ["Happy", "Sad", "Neutral"]), data: data)
        let chart = MiniChartFactory.make(from: m) as? DividerBarMiniChart
        XCTAssertNotNil(chart)
        XCTAssertEqual(chart?.entries.count, 2) // "Neutral" filtered (count == 0)
        XCTAssertEqual(chart?.entries.first(where: { $0.category == "Happy" })?.value, 2)
        XCTAssertEqual(chart?.entries.first(where: { $0.category == "Sad" })?.value, 1)
    }

    func test_categoryMultiple_returnsDividerBar() {
        let data: [DataPoint] = [.category(Date(), ["A", "B"]), .category(Date(), ["B"])]
        let m = metric(schema: .Fake.categoryMultiple(labels: ["A", "B", "C"]), data: data)
        XCTAssertTrue(MiniChartFactory.make(from: m) is DividerBarMiniChart)
    }

    // MARK: - Binary

    func test_binary_returnsDotMiniChart_withBoolMappedToDouble() {
        let data: [DataPoint] = [.binary(Date(), true), .binary(Date(), false), .binary(Date(), true)]
        let m = metric(schema: .Fake.binary(), data: data)
        let chart = MiniChartFactory.make(from: m) as? DotMiniChart
        XCTAssertNotNil(chart)
        XCTAssertEqual(chart?.data, [1.0, 0.0, 1.0])
    }

    // MARK: - Duration

    func test_duration_line_returnsLineMiniChart_withIntervals() {
        let data: [DataPoint] = [.duration(Date(), 600), .duration(Date(), 1200)]
        let m = metric(schema: .Fake.duration(chart: .line), data: data)
        let chart = MiniChartFactory.make(from: m) as? LineMiniChart
        XCTAssertNotNil(chart)
        XCTAssertEqual(chart?.data, [600, 1200])
    }

    func test_duration_bar_returnsBarMiniChart() {
        let data: [DataPoint] = [.duration(Date(), 300)]
        let m = metric(schema: .Fake.duration(chart: .bar), data: data)
        XCTAssertTrue(MiniChartFactory.make(from: m) is BarMiniChart)
    }

    // MARK: - Datetime

    func test_datetime_returnsDotMiniChart_onePerEntry() {
        let data: [DataPoint] = [.datetime(Date()), .datetime(Date())]
        let m = metric(schema: .Fake.datetime(), data: data)
        let chart = MiniChartFactory.make(from: m) as? DotMiniChart
        XCTAssertNotNil(chart)
        XCTAssertEqual(chart?.data, [1.0, 1.0])
    }
}
