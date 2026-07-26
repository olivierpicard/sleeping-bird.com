//
//  TrackerKind.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import Foundation
import SwiftUI

/// The tracker type a user can pick during manual creation. The raw value is the
/// stable identifier carried forward to the following step.
enum TrackerKind: String, CaseIterable {
    case number, duration, choices, binary, goal, date
}

extension TrackerKind {
    /// Card tint per kind, standing in for the color the AI would pick — shared
    /// by `TrackerIntentView`'s preview card and the seeded format-picker entry
    /// in `TrackerCreationFlow`.
    var previewColor: Color {
        switch self {
        case .number: .teal
        case .duration: .purple
        case .choices: .yellow
        case .binary: .green
        case .goal: .orange
        case .date: .pink
        }
    }
}
