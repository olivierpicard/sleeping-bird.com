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
        in scheme: ColorScheme,
        onAddTapped: @escaping () -> Void,
        onCardTapped: @escaping () -> Void = {}
    ) -> some View {
        // Correct once and carry the same shade across the card chrome, header,
        // and chart — matching the tracker-creation reveal.
        let color = metric.displayColor(in: scheme)
        return MetricView(
            title: metric.name,
            emoji: metric.emoji,
            value: value(for: metric),
            stat: MetricStatCalculator.stat(for: metric),
            mainColor: color,
            onAddTapped: onAddTapped,
            onCardTapped: onCardTapped,
            chart: MiniChartFactory.make(from: metric, colorOverride: color),
        )
    }

    // MARK: - Display Value

    /// The card's headline value for a metric, windowed to the aggregation
    /// bucket and reduced by its method (falling back to a type-appropriate
    /// placeholder when empty). Exposed so the tracker-creation reveal can label
    /// its sample card the same way the dashboard does.
    ///
    /// The window is anchored on the **most recent data point**, not on `now`,
    /// so a metric whose last entry was backdated still shows that entry's
    /// value instead of an empty "today".
    static func value(for metric: Metric) -> String {
        guard !metric.data.isEmpty else {
            return placeholder(for: metric.config)
        }
        let agg = metric.visual.aggregation

        switch metric.config {
        case .number(let cfg):
            let all = metric.data.compactMap { $0.numberValue }
            guard let anchor = all.map({ $0.date }).max() else {
                return placeholder(for: metric.config)
            }
            let start = windowStart(for: agg.bucket, endingAt: anchor)
            let points = all.filter { $0.date >= start }
                .sorted { $0.date < $1.date }
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

        case .duration:
            let all = metric.data.compactMap { $0.durationValue }
            guard let anchor = all.map({ $0.date }).max() else {
                return placeholder(for: metric.config)
            }
            let start = windowStart(for: agg.bucket, endingAt: anchor)
            let points = all.filter { $0.date >= start }
                .sorted { $0.date < $1.date }
            guard !points.isEmpty else {
                return placeholder(for: metric.config)
            }
            guard case .numerical(let method) = agg.method else {
                return format(duration: Int(points.last!.interval))
            }
            return format(
                duration: Int(aggregate(points.map { $0.interval }, method))
            )

        case .categorySingleChoice, .categoryMultipleChoice:
            guard case .category(_, let v) = latestPoint(of: metric) else {
                return placeholder(for: metric.config)
            }
            return v.first ?? "—"

        case .binary:
            guard case .binary(_, let flag) = latestPoint(of: metric),
                case .binary(let cfg) = metric.config
            else { return placeholder(for: metric.config) }
            return flag ? cfg.trueLabel : cfg.falseLabel

        case .datetime:
            guard case .datetime(let d) = latestPoint(of: metric) else {
                return placeholder(for: metric.config)
            }
            return relativeDay(for: d)
        }
    }

    /// "Today" / "Yesterday" / "N days ago", forced to day granularity so an
    /// older entry never collapses into "last week" — matches the phrasing
    /// discussed for fr/es, which `RelativeDateTimeFormatter` already
    /// localizes correctly ("Hier"/"Il y a N jours", "Ayer"/"Hace N días").
    private static func relativeDay(for date: Date) -> String {
        let cal = Calendar.current
        let days =
            cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: date),
                to: cal.startOfDay(for: .now)
            ).day ?? 0
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        let label = formatter.localizedString(from: DateComponents(day: -days))
        // The formatter returns sentence-lowercase ("today", "il y a 5 jours"),
        // but this is the card's headline value. Uppercase only the first
        // character — `localizedCapitalized` would title-case the whole phrase
        // ("Il Y A 5 Jours").
        return label.prefix(1).localizedUppercase + label.dropFirst()
    }

    /// The data point with the newest date — `data` is in insertion order, so a
    /// backdated entry added last must not win over a more recent one.
    private static func latestPoint(of metric: Metric) -> DataPoint? {
        metric.data.max { $0.date < $1.date }
    }

    private static func windowStart(
        for bucket: TemporalBucket?,
        endingAt now: Date
    ) -> Date {
        guard let bucket else { return .distantPast }
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
        case .duration:
            return format(duration: 0)
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

    private static func format(duration seconds: Int) -> String {
        Duration.seconds(max(0, seconds))
            .formatted(
                .units(
                    allowed: [.hours, .minutes, .seconds],
                    width: .abbreviated
                )
            )
    }
}
