//
//  MetricState.swift
//  SleepingBird
//
//  Created by Olivier Picard on 15/04/2026.
//

import Foundation
import SwiftData

@Model
public class Metric {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var color: String
    public var unit: String
    public var records: [Record]
    public var controller: ControllerType

    public init(
        id: UUID = UUID(),
        title: String,
        color: String,
        unit: String,
        records: [Record] = [],
        controller: ControllerType
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.unit = unit
        self.records = records
        self.controller = controller
    }
}

public struct Location: Codable {
    public var lat: Float
    public var lon: Float

}

public struct Record: Codable {
    public var value: String
    public var lastUpdate: Date
    public var location: Location?
    public var note: String?
}

public enum ControllerType: Codable {
    case counter
    case rawNumber(isFloating: Bool)
    case state(steps: [String])
    case binary(on: String, off: String)
    case duration
    case datetime
}
