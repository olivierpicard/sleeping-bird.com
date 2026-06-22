//
//  MetricViewFactory.swift
//  ArperBird
//
//  Created by Olivier Picard on 23/04/2026.
//

import Foundation
import SwiftUI

enum MetricViewFactory {

    static func make(
        from metric: Metric,
        onAddTapped: @escaping () -> Void,
        onCardTapped: @escaping () -> Void = {}
    ) -> some View {
        MetricView(
            title: metric.name,
            emoji: metric.emoji,
            value: value(for: metric),
            mainColor: metric.color,
            onAddTapped: onAddTapped,
            onCardTapped: onCardTapped,
            chart: MiniChartFactory.make(from: metric),
        )
    }

    // MARK: - Display Value

    private static func value(for metric: Metric) -> String {
        guard !metric.data.isEmpty else {
            return placeholder(for: metric.config)
        }
        let agg = metric.visual.aggregation
        let start = windowStart(for: agg.bucket)

        switch metric.config {
        case .number(let cfg):
            let points = metric.data.compactMap { $0.numberValue }.filter {
                $0.date >= start
            }
            guard !points.isEmpty else {
                return placeholder(for: metric.config)
            }
            guard case .numerical(let method) = agg.method else {
                return format(number: points.last!.value, cfg: cfg)
            }
            return format(
                number: aggregate(points.map { $0.value }, method),
                cfg: cfg
            )

        case .duration(let cfg):
            let points = metric.data.compactMap { $0.durationValue }.filter {
                $0.date >= start
            }
            guard !points.isEmpty else {
                return placeholder(for: metric.config)
            }
            guard case .numerical(let method) = agg.method else {
                return format(
                    duration: Int(points.last!.interval),
                    granularity: cfg.granularity
                )
            }
            return format(
                duration: Int(aggregate(points.map { $0.interval }, method)),
                granularity: cfg.granularity
            )

        case .categorySingleChoice, .categoryMultipleChoice:
            guard case .category(_, let v) = metric.data.last else {
                return placeholder(for: metric.config)
            }
            return v.first ?? "—"

        case .binary:
            guard case .binary(_, let flag) = metric.data.last,
                case .binary(let cfg) = metric.config
            else { return placeholder(for: metric.config) }
            return flag ? cfg.trueLabel : cfg.falseLabel

        case .datetime:
            guard case .datetime(let d) = metric.data.last else {
                return placeholder(for: metric.config)
            }
            return d.formatted(date: .abbreviated, time: .shortened)
        }
    }

    private static func windowStart(for bucket: TemporalBucket?) -> Date {
        guard let bucket else { return .distantPast }
        let now = Date()
        let cal = Calendar.current
        switch bucket {
        case .hourly:
            return cal.date(byAdding: .hour, value: -1, to: now) ?? now
        case .daily: return cal.startOfDay(for: now)
        case .weekly:
            return cal.date(
                from: cal.dateComponents(
                    [.yearForWeekOfYear, .weekOfYear],
                    from: now
                )
            ) ?? now
        case .monthly:
            return cal.date(
                from: cal.dateComponents([.year, .month], from: now)
            ) ?? now
        case .yearly:
            return cal.date(from: cal.dateComponents([.year], from: now)) ?? now
        }
    }

    private static func aggregate(_ values: [Double], _ method: NumericMethod)
        -> Double
    {
        switch method {
        case .sum: return values.reduce(0, +)
        case .average: return values.reduce(0, +) / Double(values.count)
        case .min: return values.min() ?? 0
        case .max: return values.max() ?? 0
        case .latest: return values.last ?? 0
        }
    }

    private static func placeholder(for config: MetricConfig) -> String {
        switch config {
        case .number(let cfg): return format(number: cfg.min, cfg: cfg)
        case .categorySingleChoice(_), .categoryMultipleChoice(_):
            return "—"
        case .binary: return "—"
        case .duration(let cfg):
            return format(duration: 0, granularity: cfg.granularity)
        case .datetime:
            return "—"
        }
    }

    // MARK: - Metadata

    private static func labels(for config: MetricConfig) -> [String] {
        switch config {
        case .categorySingleChoice(let cfg), .categoryMultipleChoice(let cfg):
            return cfg.labels
        case .binary(let cfg): return [cfg.trueLabel, cfg.falseLabel]
        default: return []
        }
    }

    private static func goal(for config: MetricConfig) -> Double? {
        guard case .number(let cfg) = config else { return nil }
        return cfg.goal
    }

    // MARK: - Formatters

    private static func format(number value: Double, cfg: NumberConfig)
        -> String
    {
        let text =
            cfg.granularity >= 1
            ? String(Int(value))
            : String(format: "%.1f", value)
        let unit = cfg.unit ?? ""
        return "\(text) \(unit)".trimmingCharacters(in: .whitespaces)
    }

    private static func format(duration seconds: Int, granularity: String)
        -> String
    {
        switch granularity {
        case "h": return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
        case "m": return "\(seconds / 60)m \(seconds % 60)s"
        case "ms": return "\(seconds * 1000)ms"
        default: return "\(seconds)s"
        }
    }
}
