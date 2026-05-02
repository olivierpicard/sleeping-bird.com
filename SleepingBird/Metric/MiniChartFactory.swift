//
//  MiniChartFactory.swift
//  SleepingBird
//
//  Created by Olivier Picard on 28/04/2026.
//

import Foundation
import SwiftUI

enum MiniChartFactory {

    static func make(from metric: Metric) -> any MiniChart {
        guard !metric.data.isEmpty else {
            return NoDataMiniChart(color: metric.color)
        }

        switch metric.config {
        case .number(let cfg):
            if metric.visual.chart == .gauge,
                let goal = cfg.goal,
                let current = metric.data.last?.numberValue?.value
            {
                return LinearGaugeMiniChart(
                    current: current,
                    goal: goal,
                    color: metric.color
                )
            }
            let values = metric.data.compactMap(\.numberValue?.value)
            switch metric.visual.chart {
            case .bar:
                return BarMiniChart(data: values, color: metric.color)
            case .heatmap:
                return DotMiniChart(data: values, color: metric.color)
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
                return NoDataMiniChart(color: metric.color)
            }
            return DividerBarMiniChart(entries: entries)

        case .binary:
            let values = metric.data.compactMap { dp -> Double? in
                guard let b = dp.binaryValue else { return nil }
                return b.value ? 1.0 : 0.0
            }
            return DotMiniChart(data: values, color: metric.color)

        case .duration:
            let values = metric.data.compactMap(\.durationValue?.interval)
            if metric.visual.chart == .bar {
                return BarMiniChart(data: values, color: metric.color)
            }
            return LineMiniChart(data: values, color: metric.color)


        }
    }
}
