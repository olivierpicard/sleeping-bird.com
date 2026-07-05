//
//  TrackerKind.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import Foundation

/// The tracker type a user can pick during manual creation. The raw value is the
/// stable identifier carried forward to the following step.
enum TrackerKind: String, CaseIterable {
    case number, duration, choices, binary, goal, date
}
