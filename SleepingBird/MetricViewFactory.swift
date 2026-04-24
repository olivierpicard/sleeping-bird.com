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
        from suggestion: MetricSuggestion,
        colorIndex: Int = 0,
        data: [Double] = [],
        generateFakeData: Bool = false,
        hideAddButton: Bool = false,
    ) -> MetricView {
        let color = color(for: colorIndex)
        let value = placeholderValue(for: suggestion.config)
        let labels = extractLabels(from: suggestion.config)
        let goal = extractGoal(from: suggestion.config)
        let resolvedData =
            generateFakeData ? fakeData(for: suggestion.config) : data

        return MetricView(
            title: suggestion.name,
            emoji: suggestion.emoji,
            value: value,
            mainColor: color,
            data: resolvedData,
            hideAddButton: hideAddButton,
            chartType: suggestion.Visual.chart,
            labels: labels,
            goal: goal,
        )
    }

    // MARK: - Fake data generation

    static func fakeData(for config: MetricConfig, count: Int = 12) -> [Double]
    {
        switch config {
        case .number(let cfg):
            return randomSeries(
                min: cfg.min,
                max: cfg.max,
                count: count,
                granularity: cfg.granularity
            )

        case .categorySingleChoice(let cfg), .categoryMultipleChoice(let cfg):
            // One count per label, randomised
            return cfg.labels.map { _ in Double(Int.random(in: 1...20)) }

        case .binary:
            // 0 or 1 for each data point
            return (0..<count).map { _ in Double(Int.random(in: 0...1)) }

        case .datetime:
            // Unix timestamps spread across the last `count` days
            let now = Date().timeIntervalSince1970
            let dayInSeconds: Double = 86_400
            return (0..<count).map { i in now - Double(count - i) * dayInSeconds
            }

        case .duration(let cfg):
            let max = Double(cfg.maxInSeconds)
            return randomSeries(min: 0, max: max, count: count, granularity: 1)
        }
    }

    private static func randomSeries(
        min: Double,
        max: Double,
        count: Int,
        granularity: Double
    ) -> [Double] {
        let step = granularity > 0 ? granularity : 1
        return (0..<count).map { _ in
            let steps = Int((max - min) / step)
            guard steps > 0 else { return min }
            return min + Double(Int.random(in: 0...steps)) * step
        }
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
