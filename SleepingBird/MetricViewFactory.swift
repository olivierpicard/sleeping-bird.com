//
//  MetricViewFactory.swift
//  SleepingBird
//
//  Created by Olivier Picard on 23/04/2026.
//

import SwiftUI

enum MetricViewFactory {

    /// Palette cycled by index so adjacent metrics get distinct colors.
    private static let palette: [Color] = [
        .blue, .green, .orange, .indigo, .red, .teal, .purple, .pink,
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

    // MARK: - Public

    static func makeView(
        from suggestion: MetricSchema,
        colorIndex: Int = 0,
        data: [Double] = [],
    ) -> MetricView {
        let color = color(for: colorIndex)
        let value = placeholderValue(for: suggestion.config)
        let labels = extractLabels(from: suggestion.config)
        let goal = extractGoal(from: suggestion.config)

        return MetricView(
            title: suggestion.name,
            emoji: suggestion.emoji,
            value: value,
            mainColor: color,
            data: data,
            chartType: suggestion.visual.chart,
            labels: labels,
            goal: goal,
        )
    }

    // MARK: - Config extraction

    private static func extractLabels(from config: MetricConfig) -> [String] {
        switch config {
        case .categorySingleChoice(let cfg),
            .categoryMultipleChoice(let cfg):
            return cfg.labels
        case .binary(let cfg):
            return [cfg.trueLabel, cfg.falseLabel]
        default:
            return []
        }
    }

    private static func extractGoal(from config: MetricConfig) -> Double? {
        switch config {
        case .number(let cfg):
            return cfg.goal
        default:
            return nil
        }
    }

    // MARK: - Value formatting

    private static func placeholderValue(for config: MetricConfig) -> String {
        switch config {
        case .number(let cfg):
            return formatNumber(cfg)
        case .categorySingleChoice(let cfg),
            .categoryMultipleChoice(let cfg):
            return cfg.labels.first ?? "—"
        case .binary(let cfg):
            return cfg.trueLabel
        case .datetime:
            return "—"
        case .duration(let cfg):
            return formatDuration(seconds: 0, granularity: cfg.granularity)
        }
    }

    private static func formatNumber(_ cfg: NumberConfig) -> String {
        let formatted =
            cfg.granularity >= 1
            ? String(Int(cfg.min))
            : String(format: "%.1f", cfg.min)

        if let unit = cfg.unit {
            return "\(formatted) \(unit)"
        }
        return formatted
    }

    private static func formatDuration(
        seconds: Int,
        granularity: String
    ) -> String {
        switch granularity {
        case "h":
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return "\(h)h \(m)m"
        case "m":
            let m = seconds / 60
            let s = seconds % 60
            return "\(m)m \(s)s"
        case "s":
            return "\(seconds)s"
        case "ms":
            return "\(seconds * 1000)ms"
        default:
            return "\(seconds)s"
        }
    }
}
