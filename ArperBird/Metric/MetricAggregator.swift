//
//  MetricAggregator.swift
//  ArperBird
//
//  Created by Olivier Picard on 03/05/2026.
//

import Foundation
import SwiftUI

enum MetricAggregator {
    static func categoryEntries(
        from points: [DataPoint],
        range: TimeRange
    ) -> [StackedBarChartView.Entry] {
        let calendar = Calendar.current
        let component = range.bucketComponent

        var counts: [Date: [String: Int]] = [:]
        for point in points {
            guard case .category(let date, let labels) = point,
                let start = calendar.dateInterval(of: component, for: date)?.start
            else { continue }
            for label in labels {
                counts[start, default: [:]][label, default: 0] += 1
            }
        }

        var entries: [StackedBarChartView.Entry] = []
        for (bucketStart, byLabel) in counts {
            for (label, count) in byLabel {
                entries.append(
                    StackedBarChartView.Entry(
                        date: bucketStart,
                        label: label,
                        value: Double(count)
                    )
                )
            }
        }
        entries.sort { $0.date < $1.date }
        return entries
    }

    static func bins(
        from points: [DataPoint],
        range: TimeRange,
        method: NumericMethod,
        behavior: MetricBehavior
    ) -> [ChartBin] {
        bins(
            from: points,
            component: range.bucketComponent,
            method: method,
            behavior: behavior
        )
    }

    static func bins(
        from points: [DataPoint],
        component: Calendar.Component,
        method: NumericMethod,
        behavior: MetricBehavior
    ) -> [ChartBin] {
        let calendar = Calendar.current

        let raw: [(Date, Double)] = points.compactMap { point in
            switch point {
            case .number(let d, let v): return (d, v)
            case .duration(let d, let t): return (d, t)
            default: return nil
            }
        }
        guard !raw.isEmpty else { return [] }

        var groups: [Date: [(Date, Double)]] = [:]
        for (date, value) in raw {
            guard
                let start = calendar.dateInterval(of: component, for: date)?
                    .start
            else { continue }
            groups[start, default: []].append((date, value))
        }

        var bins: [ChartBin] = groups.map { bucketStart, items in
            ChartBin(
                date: bucketStart,
                value: aggregate(items, method: method),
                count: items.count
            )
        }
        bins.sort { $0.date < $1.date }

        if behavior == .cumulative,
            let first = bins.first?.date,
            let last = bins.last?.date
        {
            return fillGaps(
                bins,
                from: first,
                to: last,
                stepping: component,
                calendar: calendar
            )
        }

        return bins
    }

    private static func aggregate(
        _ items: [(Date, Double)],
        method: NumericMethod
    ) -> Double {
        guard !items.isEmpty else { return 0 }
        let values = items.map { $0.1 }
        switch method {
        case .sum: return values.reduce(0, +)
        case .average: return values.reduce(0, +) / Double(values.count)
        case .min: return values.min() ?? 0
        case .max: return values.max() ?? 0
        case .latest:
            return items.max(by: { $0.0 < $1.0 })?.1 ?? values.last ?? 0
        }
    }

    private static func fillGaps(
        _ bins: [ChartBin],
        from start: Date,
        to end: Date,
        stepping component: Calendar.Component,
        calendar: Calendar
    ) -> [ChartBin] {
        var byDate = Dictionary(uniqueKeysWithValues: bins.map { ($0.date, $0) })
        var filled: [ChartBin] = []
        var cursor = start
        while cursor <= end {
            if let existing = byDate[cursor] {
                filled.append(existing)
            } else {
                filled.append(ChartBin(date: cursor, value: 0, count: 0))
            }
            byDate[cursor] = nil
            guard
                let next = calendar.date(
                    byAdding: component,
                    value: 1,
                    to: cursor
                )
            else { break }
            cursor = next
        }
        return filled
    }
}
