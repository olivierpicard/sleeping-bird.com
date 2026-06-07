//
//  MiniChartFactory.swift
//  ArperBird
//
//  Created by Olivier Picard on 28/04/2026.
//

import Foundation
import SwiftUI

enum MiniChartFactory {

    static func make(from metric: Metric) -> any MiniChart {
        guard !metric.data.isEmpty else {
            return NoDataMiniChart()
        }

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
                        color: metric.color
                    )
                }
            }
            let values = metric.data.compactMap(\.numberValue?.value)
            switch metric.visual.chart {
            case .bar:
                return BarMiniChart(data: values, color: metric.color)
            default:
                return LineMiniChart(data: values, color: metric.color)
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
            let dates = metric.data.compactMap { dp -> Date? in
                guard let b = dp.binaryValue, b.value else { return nil }
                return b.date
            }
            return TrailingCalendarMiniChart(data: dates, color: metric.color)

        case .duration:
            let values = metric.data.compactMap(\.durationValue?.interval)
            if metric.visual.chart == .bar {
                return BarMiniChart(data: values, color: metric.color)
            }
            return LineMiniChart(data: values, color: metric.color)

        case .datetime:
            let dates = metric.data.compactMap(\.datetimeValue)
            return EventCalendarMiniChart(data: dates, color: metric.color)
        }
    }
}
