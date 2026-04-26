//
//  Metric.swift
//  SleepingBird
//
//  Created by Olivier Picard on 24/04/2026.
//

import Foundation
import SwiftUI
import SwiftData

@Model
class Metric: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var config: MetricConfig
    var visual: MetricVisual
    var data: [DataPoint]

    @Transient
    var color: Color {
        get { Color(hex: colorHex) }
        set { colorHex = newValue.hexString }
    }

    init(
        from schema: MetricSchema,
        id: UUID = UUID(),
        color: Color = .randomMetricColor(),
        data: [DataPoint] = []
    ) {
        self.id = id
        self.name = schema.name
        self.emoji = schema.emoji.isEmpty ? "🫥" : schema.emoji
        self.colorHex = color.hexString
        self.config = schema.config
        self.visual = schema.visual
        self.data = data
    }
}

enum DataPoint: Codable {
    case number(Date, Double)
    case category(Date, [String])
    case binary(Date, Bool)
    case datetime(Date)
    case duration(Date, TimeInterval)
}

