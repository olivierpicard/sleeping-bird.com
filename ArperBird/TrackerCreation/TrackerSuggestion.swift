//
//  TrackerSuggestion.swift
//  ArperBird
//
//  Created by Olivier Picard on 03/07/2026.
//

import Foundation

/// A curated tracker idea offered as a tappable chip (today on the empty
/// dashboard). Unlike the free-form name the user types in the flow, a
/// suggestion also carries its `TrackerKind` — that's what lets a tap seed
/// `TrackerCreationFlow` past the type and name steps, straight into the
/// kind's AI loading step.
struct TrackerSuggestion: Identifiable {
    /// The tracker name, localized separately from the emoji so the seeded
    /// `TrackerCreationModel.name` (which the AI completions key off) stays a
    /// clean name in the user's language.
    let name: LocalizedStringResource
    /// Chip decoration only — the flow's loading step fetches the metric's
    /// real emoji from the AI, same as a typed name.
    let emoji: String
    let kind: TrackerKind

    var id: String { name.key }

    var localizedName: String { String(localized: name) }

    /// The chip label: localized name plus emoji.
    var label: String { "\(localizedName) \(emoji)" }

    /// The curated list shown on the empty dashboard. Quantity-style ideas use
    /// `.number` rather than `.goal` — the number path runs straight from the
    /// loading step to the reveal (unit, max, and behavior stay editable via
    /// the recap chips), keeping a seeded creation at two taps.
    static let defaults: [TrackerSuggestion] = [
        .init(name: "Water", emoji: "💧", kind: .number),
        .init(name: "Maintenance", emoji: "💰🚗", kind: .number),
        .init(name: "Sleep", emoji: "💤", kind: .duration),
        .init(name: "Pain", emoji: "😖", kind: .number),
        .init(name: "Mood", emoji: "😁", kind: .choices),
        .init(name: "Proteins", emoji: "🥩🌱", kind: .number),
        .init(name: "Meditation", emoji: "⏱️🧘", kind: .duration),
        .init(name: "Coffee", emoji: "☕️", kind: .number),
        .init(name: "Fuel Spend", emoji: "⛽️", kind: .number),
    ]
}
