//
//  TrackerSuggestion.swift
//  ArperBird
//
//  Created by Olivier Picard on 03/07/2026.
//

import Foundation

/// A curated tracker idea offered as a tappable chip (today on the empty
/// dashboard). Beyond its name, a suggestion carries the ordered logging
/// `formats` the intent screen offers when it's tapped — so "Cups of Coffee"
/// can offer just a number while "Music Practice" offers time-or-yes/no,
/// instead of every idea inheriting the same generic per-kind pair.
struct TrackerSuggestion: Identifiable {
    /// Short chip text, localized (e.g. "Maintenance").
    let label: LocalizedStringResource
    /// The tracker name seeded into `TrackerCreationModel.name` and shown on
    /// the card — may be more specific than the chip (e.g. "Car Maintenance
    /// Cost"). Kept explicit enough that the name alone steers the AI, since
    /// there's no separate hint.
    let name: LocalizedStringResource
    /// The single emoji shown on the intent preview card. Kept to one glyph so
    /// the card header's fixed emoji box never overflows to "…" (the final
    /// persisted metric still gets its emoji from the AI loading step).
    let emoji: String
    /// Chip decoration, which may pair a second emoji for richness (e.g.
    /// "⏱️🎸" — a duration hint beside the subject). Defaults to `emoji`, and
    /// never reaches the card. Distinct from `emoji` for the same reason `name`
    /// is distinct from `label`.
    let chipEmoji: String
    /// The tracker's underlying kind. Seeds the default `formats` and, for the
    /// examples list, groups ideas per type.
    let kind: TrackerKind
    /// The logging formats the intent screen offers for this idea, best-fit
    /// first (the first is the variant shown on open). Defaults to a sensible
    /// per-kind list (`defaultFormats(for:)`); override when the name warrants
    /// richer or narrower options — e.g. a countable with a natural target
    /// leads with `.goal`, a pure cost offers only `.number`.
    let formats: [IntentFormatType]

    init(
        label: LocalizedStringResource,
        name: LocalizedStringResource? = nil,
        emoji: String,
        chipEmoji: String? = nil,
        kind: TrackerKind,
        formats: [IntentFormatType]? = nil
    ) {
        self.label = label
        self.name = name ?? label
        self.emoji = emoji
        self.chipEmoji = chipEmoji ?? emoji
        self.kind = kind
        self.formats = formats ?? Self.defaultFormats(for: kind)
    }

    /// The logging formats offered for a kind when a suggestion doesn't spell
    /// its own out. Keyed per kind, each pairing chosen so the alternate always
    /// makes sense: a duration reads as "how long / did I", a goal as
    /// "target / plain number"; a bare number offers no yes/no it can't honor.
    static func defaultFormats(for kind: TrackerKind) -> [IntentFormatType] {
        switch kind {
        case .number: [.number]
        case .duration: [.duration, .binary]
        case .choices: [.choices]
        case .binary: [.binary]
        case .date: [.date]
        case .goal: [.goal, .number]
        }
    }

    var id: String { label.key }

    var localizedName: String { String(localized: name) }

    /// The chip text: short label plus the (possibly two-emoji) chip decoration.
    var chipText: String { "\(String(localized: label)) \(chipEmoji)" }

    /// The curated list shown on the empty dashboard. Most ideas take their
    /// kind's default formats; the ones with a natural daily target (water,
    /// protein) lead with `.goal` so the intent card opens on the gauge.
    static let defaults: [TrackerSuggestion] = [
        .init(
            label: "Water",
            name: "Glasses of Water",
            emoji: "💧",
            kind: .number,
            formats: [.goal, .number]
        ),
        .init(
            label: "Maintenance",
            name: "Car Maintenance Cost",
            emoji: "💰",
            chipEmoji: "💰🚗",
            kind: .number
        ),
        .init(
            label: "Practice",
            name: "Music Practice",
            emoji: "🎸",
            chipEmoji: "⏱️🎸",
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
            emoji: "🥩",
            chipEmoji: "🥩🌱",
            kind: .number,
            formats: [.goal, .number]
        ),
        .init(
            label: "Meditation",
            emoji: "🧘",
            chipEmoji: "⏱️🧘",
            kind: .duration
        ),
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
                .init(
                    label: "No Alcohol",
                    emoji: "🍺",
                    chipEmoji: "🚫🍺",
                    kind: .binary
                ),
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
