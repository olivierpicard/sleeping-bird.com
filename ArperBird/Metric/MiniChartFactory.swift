//
//  MiniChartFactory.swift
//  ArperBird
//
//  Created by Olivier Picard on 28/04/2026.
//

import Foundation
import SwiftUI

enum MiniChartFactory {

    /// `colorOverride` lets a caller render the chart in a color other than the
    /// metric's own — e.g. the tracker-creation reveal, which shows the chart in
    /// gray so the card chrome carries the color instead.
    static func make(from metric: Metric, colorOverride: Color? = nil) -> any MiniChart {
        guard !metric.data.isEmpty else {
            return NoDataMiniChart()
        }

        let color = colorOverride ?? metric.color

        switch metric.config {
        case .number(let cfg):
            if metric.visual.chart == .dailyGauge, let goal = cfg.goal {
                let today = Calendar.current.startOfDay(for: Date())
                let current = metric.data.compactMap(\.numberValue).filter {
                    $0.date >= today
                }.map(\.value).reduce(0, +)
                if current > 0 {
                    return LinearGaugeMiniChart(
                        current: current,
                        goal: goal,
                        color: color
                    )
                }
            }
            let values = metric.data.compactMap(\.numberValue?.value)
            switch metric.visual.chart {
            case .bar:
                let bars =
                    cfg.behavior == .cumulative
                    ? cumulativeBarValues(for: metric) : values
                return BarMiniChart(data: bars, color: color)
            default:
                return LineMiniChart(data: values, color: color)
            }

        case .categorySingleChoice(let cfg), .categoryMultipleChoice(let cfg):
            let entries = cfg.labels.compactMap {
                label -> DividerBarMiniChart.Entry? in
                let count = metric.data.reduce(0.0) { acc, point in
                    guard case .category(_, let v) = point, v.contains(label)
                    else { return acc }
                    return acc + 1
                }
                guard count > 0 else { return nil }
                return DividerBarMiniChart.Entry(category: label, value: count)
            }
            guard !entries.isEmpty else {
                return NoDataMiniChart()
            }
            return DividerBarMiniChart(entries: entries)

        case .binary:
            var trueDates: [Date] = []
            var falseDates: [Date] = []
            for dp in metric.data {
                guard let b = dp.binaryValue else { continue }
                if b.value {
                    trueDates.append(b.date)
                } else {
                    falseDates.append(b.date)
                }
            }
            return TrailingCalendarMiniChart(
                data: trueDates,
                falseData: falseDates,
                color: color
            )

        case .duration(let cfg):
            let values = metric.data.compactMap(\.durationValue?.interval)
            if metric.visual.chart == .bar {
                let bars =
                    cfg.behavior == .cumulative
                    ? cumulativeBarValues(for: metric) : values
                return BarMiniChart(data: bars, color: color)
            }
            return LineMiniChart(data: values, color: color)

        case .datetime:
            let dates = metric.data.compactMap(\.datetimeValue)
            return EventCalendarMiniChart(data: dates, color: color)
        }
    }

    /// Bars for a cumulative number/duration metric: one bar per `aggregation`
    /// period (daily when unset), reducing by the metric's method. The
    /// in-progress period is the last bin, which keeps growing as new points
    /// land in it rather than spawning a new bar.
    private static func cumulativeBarValues(for metric: Metric) -> [Double] {
        let agg = metric.visual.aggregation
        let method: NumericMethod = {
            if case .numerical(let m) = agg.method { return m }
            return .sum
        }()
        let bins = MetricAggregator.bins(
            from: metric.data,
            component: (agg.bucket ?? .daily).bucketComponent,
            method: method,
            behavior: .cumulative
        )
        return bins.map(\.value)
    }
}
