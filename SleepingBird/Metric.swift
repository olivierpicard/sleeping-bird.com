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
        self.data = data
    }
}

extension Color {
    static func randomMetricColor() -> Color {
        Color(hue: .random(in: 0...1), saturation: 0.65, brightness: 0.85)
    }
}
