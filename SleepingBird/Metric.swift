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

extension Color {
    static func randomMetricColor() -> Color {
        Color(hue: .random(in: 0...1), saturation: 0.65, brightness: 0.85)
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
