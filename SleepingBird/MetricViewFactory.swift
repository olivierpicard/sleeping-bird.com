//
//  MetricViewFactory.swift
//  SleepingBird
//
//  Created by Olivier Picard on 23/04/2026.
//

import Foundation
import SwiftUI

enum MetricViewFactory {

    static func build(from metric: Metric) -> MetricView {
        MetricView(
            title: metric.name,
            emoji: metric.emoji,
            value: value(for: metric),
            mainColor: metric.color,
            data: chartData(for: metric),
            chartType: metric.visual.chart,
            labels: labels(for: metric.config),
            goal: goal(for: metric.config)
        )
    }

    // MARK: - Display Value

    private static func value(for metric: Metric) -> String {
        guard let last = metric.data.last else {
            return placeholder(for: metric.config)
        }
        switch last {
        case .number(_, let v):
            guard case .number(let cfg) = metric.config else {
                return placeholder(for: metric.config)
            }
            return format(number: v, cfg: cfg)
        case .category(_, let v):
            return v.first ?? "—"
        case .binary(_, let flag):
            guard case .binary(let cfg) = metric.config else {
                return placeholder(for: metric.config)
            }
            return flag ? cfg.trueLabel : cfg.falseLabel
        case .datetime(let d):
            return d.formatted(date: .abbreviated, time: .shortened)
        case .duration(_, let t):
            guard case .duration(let cfg) = metric.config else {
                return placeholder(for: metric.config)
            }
            return format(duration: Int(t), granularity: cfg.granularity)
        }
    }

    private static func placeholder(for config: MetricConfig) -> String {
        switch config {
        case .number(let cfg): return format(number: cfg.min, cfg: cfg)
        case .categorySingleChoice(let cfg),
            .categoryMultipleChoice(let cfg):
            return cfg.labels.first ?? "—"
        case .binary(let cfg): return cfg.trueLabel
        case .datetime: return "—"
        case .duration(let cfg):
            return format(duration: 0, granularity: cfg.granularity)
        }
    }

    // MARK: - Chart Data

    private static func chartData(for metric: Metric) -> [Double] {
        switch metric.config {
        case .number:
            return metric.data.compactMap {
                guard case .number(_, let v) = $0 else { return nil }
                return v
            }
        case .binary:
            return metric.data.compactMap {
                guard case .binary(_, let b) = $0 else { return nil }
                return b ? 1.0 : 0.0
            }
        case .duration:
            return metric.data.compactMap {
                guard case .duration(_, let t) = $0 else { return nil }
                return Double(t)
            }
        case .categorySingleChoice(let cfg), .categoryMultipleChoice(let cfg):
            return categoryFrequencies(in: metric.data, for: cfg.labels)
        case .datetime:
            return []
        }
    }

    private static func categoryFrequencies(
        in data: [DataPoint],
        for labels: [String]
    ) -> [Double] {
        labels.map { label in
            data.reduce(0.0) { count, point in
                guard case .category(_, let v) = point, v.contains(label) else {
                    return count
                }
                return count + 1
            }
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
        return cfg.unit.map { "\(text) \($0)" } ?? text
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
