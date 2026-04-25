//
//  Metric.swift
//  SleepingBird
//
//  Created by Olivier Picard on 24/04/2026.
//

import Foundation
import SwiftUI

struct Metric: Identifiable {
    let id: UUID
    var name: String
    var emoji: Character
    var color: Color
    var config: MetricConfig
    var visual: MetricVisual
    var data: [DataPoint]
}

enum DataPoint {
    case number(Date, Double)
    case category(Date, [String])
    case binary(Date, Bool)
    case datetime(Date)
    case duration(Date, TimeInterval)
}

extension Metric {
    init(
        from schema: MetricSchema,
        id: UUID = UUID(),
        color: Color = .randomMetricColor(),
        data: [DataPoint] = []
    ) {
        self.id = id
        self.name = schema.name
        self.emoji = schema.emoji.first ?? "🫥"
        self.color = color
        self.config = schema.config
        self.visual = schema.visual
        #if DEBUG
        self.data = data.isEmpty ? Metric.fakeData(for: schema.config) : data
        #else
        self.data = data
        #endif
    }
}

#if DEBUG
extension Metric {
    static func fakeData(for config: MetricConfig, days: Int = 14) -> [DataPoint] {
        let now = Date()
        let calendar = Calendar.current
        return (0..<days).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            switch config {
            case .number(let cfg):
                let range = cfg.max - cfg.min
                let value = cfg.min + Double.random(in: 0...1) * range
                let snapped = (value / cfg.granularity).rounded() * cfg.granularity
                return .number(date, min(snapped, cfg.max))
            case .categorySingleChoice(let cfg), .categoryMultipleChoice(let cfg):
                let count = config.isMultiple ? Int.random(in: 1...min(3, cfg.labels.count)) : 1
                let picked = Array(cfg.labels.shuffled().prefix(count))
                return .category(date, picked)
            case .binary:
                return .binary(date, Double.random(in: 0...1) > 0.3)
            case .datetime:
                let hour = Int.random(in: 5...9)
                let minute = Int.random(in: 0...59)
                let wake = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
                return .datetime(wake)
            case .duration(let cfg):
                let max = TimeInterval(cfg.maxInSeconds)
                return .duration(date, TimeInterval.random(in: max * 0.3...max))
            }
        }
    }
}

private extension MetricConfig {
    var isMultiple: Bool {
        if case .categoryMultipleChoice = self { return true }
        return false
    }
}
#endif

extension Color {
    static func randomMetricColor() -> Color {
        Color(hue: .random(in: 0...1), saturation: 0.65, brightness: 0.85)
    }
}
