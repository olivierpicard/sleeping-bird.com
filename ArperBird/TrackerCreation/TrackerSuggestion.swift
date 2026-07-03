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
        .init(name: "Practice", emoji: "⏱️🎸", kind: .duration),
        .init(name: "Pain", emoji: "😖", kind: .number),
        .init(name: "Mood", emoji: "😁", kind: .choices),
        .init(name: "Proteins", emoji: "🥩🌱", kind: .number),
        .init(name: "Meditation", emoji: "⏱️🧘", kind: .duration),
        .init(name: "Coffee", emoji: "☕️", kind: .number),
        .init(name: "Fuel Spend", emoji: "⛽️", kind: .number),
        .init(name: "Time Outside", emoji: "🌳", kind: .duration),
    ]

    /// Curated ideas for one tracker type, shown as tappable chips on that
    /// type's page in the type-picker carousel — the interactive counterpart
    /// of the static examples caption they replace. Each list is hand-picked
    /// for its kind (unlike `defaults`, which skews `.number` for the
    /// dashboard), so a tap both teaches what the type is for and shortcuts
    /// straight into its flow.
    static func examples(for kind: TrackerKind) -> [TrackerSuggestion] {
        switch kind {
        case .duration:
            [
                .init(name: "Time Outside", emoji: "🌳", kind: .duration),
                .init(name: "Practice", emoji: "🎸", kind: .duration),
                .init(name: "Reading", emoji: "📖", kind: .duration),
                .init(name: "Focus Work", emoji: "🧑‍💻", kind: .duration),
                .init(name: "Gaming", emoji: "🎮", kind: .duration),
            ]
        case .binary:
            [
                .init(name: "Took Meds", emoji: "💊", kind: .binary),
                .init(name: "Gym", emoji: "🏋️", kind: .binary),
                .init(name: "Ate Healthy", emoji: "🥗", kind: .binary),
                .init(name: "Flossed", emoji: "🦷", kind: .binary),
                .init(name: "No Alcohol", emoji: "🚫🍺", kind: .binary),
            ]
        case .choices:
            [
                .init(name: "Mood", emoji: "😁", kind: .choices),
                .init(name: "Meal Type", emoji: "🍽️", kind: .choices),
                .init(name: "Symptoms", emoji: "🤒", kind: .choices),
                .init(name: "Workout Type", emoji: "🏃", kind: .choices),
                .init(name: "Acne Trigger", emoji: "🧖", kind: .choices),
            ]
        case .date:
            [
                .init(name: "Period", emoji: "🩸", kind: .date),
                .init(name: "Haircut", emoji: "💇", kind: .date),
                .init(name: "Allergy", emoji: "🤧", kind: .date),
                .init(name: "Watered Plants", emoji: "🪴", kind: .date),
                .init(name: "Sheets Changed", emoji: "🛏️", kind: .date),
                .init(name: "Migraine", emoji: "🤕", kind: .date),
            ]
        case .goal:
            [
                .init(name: "Water", emoji: "💧", kind: .goal),
                .init(name: "Pushups", emoji: "💪", kind: .goal),
                .init(name: "Veggies", emoji: "🥦", kind: .goal),
                .init(name: "New Words", emoji: "🗣️", kind: .goal),
                .init(name: "Gratitudes", emoji: "✨", kind: .goal),
                .init(name: "Chores", emoji: "🧹", kind: .goal),
            ]
        case .number:
            [
                .init(name: "Fuel Spend", emoji: "⛽️", kind: .number),
                .init(name: "Waist", emoji: "📏", kind: .number),
                .init(name: "Cigarettes", emoji: "🚬", kind: .number),
                .init(name: "Coffee", emoji: "☕️", kind: .number),
                .init(name: "Pain", emoji: "😖", kind: .number),
            ]
        }
    }
}
