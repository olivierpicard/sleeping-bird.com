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

    enum AppendError: Error {
        case typeMismatch(expected: String, got: String)
    }

    func append(_ point: DataPoint) throws {
        let valid: Bool
        switch (config, point) {
        case (.number, .number): valid = true
        case (.categorySingleChoice, .category), (.categoryMultipleChoice, .category): valid = true
        case (.binary, .binary): valid = true
        case (.datetime, .datetime): valid = true
        case (.duration, .duration): valid = true
        default: valid = false
        }
        guard valid else {
            throw AppendError.typeMismatch(
                expected: "\(config)",
                got: "\(point)"
            )
        }
        data.append(point)
    }

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

    var numberValue: (date: Date, value: Double)? {
        guard case .number(let date, let value) = self else { return nil }
        return (date, value)
    }

    var categoryValue: (date: Date, labels: [String])? {
        guard case .category(let date, let labels) = self else { return nil }
        return (date, labels)
    }

    var binaryValue: (date: Date, value: Bool)? {
        guard case .binary(let date, let value) = self else { return nil }
        return (date, value)
    }

    var datetimeValue: Date? {
        guard case .datetime(let date) = self else { return nil }
        return date
    }

    var durationValue: (date: Date, interval: TimeInterval)? {
        guard case .duration(let date, let interval) = self else { return nil }
        return (date, interval)
    }
}

