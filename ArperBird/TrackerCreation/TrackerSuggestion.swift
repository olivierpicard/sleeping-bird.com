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
    /// Short chip text, localized (e.g. "Maintenance").
    let label: LocalizedStringResource
    /// The tracker name seeded into `TrackerCreationModel.name` and shown on
    /// the card — may be more specific than the chip (e.g. "Car Maintenance
    /// Cost"). Kept explicit enough that the name alone steers the AI, since
    /// there's no separate hint.
    let name: LocalizedStringResource
    /// Chip decoration only — the flow's loading step fetches the metric's
    /// real emoji from the AI, same as a typed name.
    let emoji: String
    let kind: TrackerKind

    init(
        label: LocalizedStringResource,
        name: LocalizedStringResource? = nil,
        emoji: String,
        kind: TrackerKind
    ) {
        self.label = label
        self.name = name ?? label
        self.emoji = emoji
        self.kind = kind
    }

    var id: String { label.key }

    var localizedName: String { String(localized: name) }

    /// The chip text: short label plus emoji.
    var chipText: String { "\(String(localized: label)) \(emoji)" }

    /// The curated list shown on the empty dashboard. Quantity-style ideas use
    /// `.number` rather than `.goal` — the number path runs straight from the
    /// loading step to the reveal (unit, max, and behavior stay editable via
    /// the recap chips), keeping a seeded creation at two taps.
    static let defaults: [TrackerSuggestion] = [
        .init(
            label: "Water",
            name: "Glasses of Water",
            emoji: "💧",
            kind: .number
        ),
        .init(
            label: "Maintenance",
            name: "Car Maintenance Cost",
            emoji: "💰🚗",
            kind: .number
        ),
        .init(
            label: "Practice",
            name: "Music Practice",
            emoji: "⏱️🎸",
            kind: .duration
        ),
        .init(
            label: "Pain",
            name: "Pain Level",
            emoji: "😖",
            kind: .number
        ),
        .init(label: "Mood", emoji: "😁", kind: .choices),
        .init(
            label: "Proteins",
            name: "Grams of Protein",
            emoji: "🥩🌱",
            kind: .number
        ),
        .init(label: "Meditation", emoji: "⏱️🧘", kind: .duration),
        .init(
            label: "Coffee",
            name: "Cups of Coffee",
            emoji: "☕️",
            kind: .number
        ),
        .init(
            label: "Fuel Spend",
            name: "Fuel Cost",
            emoji: "⛽️",
            kind: .number
        ),
        .init(label: "Time Outside", emoji: "🌳", kind: .duration),
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
                .init(label: "Time Outside", emoji: "🌳", kind: .duration),
                .init(
                    label: "Practice",
                    name: "Music Practice",
                    emoji: "🎸",
                    kind: .duration
                ),
                .init(label: "Reading", emoji: "📖", kind: .duration),
                .init(label: "Focus Work", emoji: "🧑‍💻", kind: .duration),
                .init(label: "Gaming", emoji: "🎮", kind: .duration),
            ]
        case .binary:
            [
                .init(label: "Took Meds", emoji: "💊", kind: .binary),
                .init(label: "Gym", emoji: "🏋️", kind: .binary),
                .init(label: "Ate Healthy", emoji: "🥗", kind: .binary),
                .init(label: "Flossed", emoji: "🦷", kind: .binary),
                .init(label: "No Alcohol", emoji: "🚫🍺", kind: .binary),
            ]
        case .choices:
            [
                .init(label: "Mood", emoji: "😁", kind: .choices),
                .init(label: "Sleep Quality", emoji: "😴", kind: .choices),
                .init(label: "Social Contact", emoji: "👥", kind: .choices),
                .init(label: "Meal Type", emoji: "🍽️", kind: .choices),
                .init(label: "Cravings", emoji: "🍫", kind: .choices),
            ]
        case .date:
            [
                .init(label: "Period", emoji: "🩸", kind: .date),
                .init(label: "Haircut", emoji: "💇", kind: .date),
                .init(label: "Allergy", emoji: "🤧", kind: .date),
                .init(label: "Watered Plants", emoji: "🪴", kind: .date),
                .init(label: "Migraine", emoji: "🤕", kind: .date),
            ]
        case .goal:
            [
                .init(
                    label: "Water",
                    name: "Glasses of Water",
                    emoji: "💧",
                    kind: .goal
                ),
                .init(label: "Pushups", emoji: "💪", kind: .goal),
                .init(
                    label: "Veggies",
                    name: "Veggie Servings",
                    emoji: "🥦",
                    kind: .goal
                ),
                .init(label: "New Words", emoji: "🗣️", kind: .goal),
                .init(label: "Chores", emoji: "🧹", kind: .goal),
            ]
        case .number:
            [
                .init(
                    label: "Fuel Spend",
                    name: "Fuel Cost",
                    emoji: "⛽️",
                    kind: .number
                ),
                .init(label: "Waist", emoji: "📏", kind: .number),
                .init(label: "Cigarettes", emoji: "🚬", kind: .number),
                .init(
                    label: "Coffee",
                    name: "Cups of Coffee",
                    emoji: "☕️",
                    kind: .number
                ),
                .init(
                    label: "Pain",
                    name: "Pain Level",
                    emoji: "😖",
                    kind: .number
                ),
            ]
        }
    }
}
