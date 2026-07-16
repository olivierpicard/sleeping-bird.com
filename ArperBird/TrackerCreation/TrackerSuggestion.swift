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
    let trackerName: LocalizedStringResource
    /// The text offered as the intent field's prompt when this suggestion is
    /// typed in (e.g. "Track the water I drink") — distinct from `trackerName`
    /// so the card can carry a concise name while the field reads as a full
    /// sentence. Defaults to `trackerName` when a suggestion has no natural
    /// sentence of its own (every curated example besides the empty-dashboard
    /// defaults).
    let instruction: LocalizedStringResource
    /// The single emoji shown on the intent preview card. Kept to one glyph so
    /// the card header's fixed emoji box never overflows to "…" (the final
    /// persisted metric still gets its emoji from the AI loading step).
    let emoji: String
    /// Chip decoration, which may pair a second emoji for richness (e.g.
    /// "⏱️🎸" — a duration hint beside the subject). Defaults to `emoji`, and
    /// never reaches the card. Distinct from `emoji` for the same reason
    /// `trackerName` is distinct from `label`.
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
        trackerName: LocalizedStringResource? = nil,
        instruction: LocalizedStringResource? = nil,
        emoji: String,
        chipEmoji: String? = nil,
        kind: TrackerKind,
        formats: [IntentFormatType]? = nil
    ) {
        self.label = label
        self.trackerName = trackerName ?? label
        self.instruction = instruction ?? self.trackerName
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

    var localizedTrackerName: String { String(localized: trackerName) }

    var localizedInstruction: String { String(localized: instruction) }

    /// Builds a suggestion from a free-text AI intent resolution, so a typed
    /// prompt can route through the exact same seeded creation flow the curated
    /// chips use. The AI title is a runtime string (not a catalog key), which a
    /// `LocalizedStringResource(stringLiteral:)` carries verbatim — `id` and
    /// `localizedTrackerName` fall out as that raw string. The best-fit (first)
    /// format's kind seeds the tint, matching `TrackerIntentView`'s own per-kind
    /// color.
    init(from completion: IntentCompletion) {
        self.init(
            label: LocalizedStringResource(stringLiteral: completion.title),
            emoji: completion.emoji.isEmpty ? "📊" : completion.emoji,
            kind: completion.formats.first?.kind ?? .number,
            // `IntentCompletion.formats` is guaranteed 1...3 by its `@Guide`, but
            // fall back to the kind's defaults if it ever arrives empty rather
            // than seeding a formatless (and un-routable) suggestion.
            formats: completion.formats.isEmpty ? nil : completion.formats
        )
    }

    /// The chip text: short label plus the (possibly two-emoji) chip decoration.
    var chipText: String { "\(String(localized: label)) \(chipEmoji)" }

    /// The curated list shown on the empty dashboard. Most ideas take their
    /// kind's default formats; the ones with a natural daily target (water,
    /// protein) lead with `.goal` so the intent card opens on the gauge.
    static let defaults: [TrackerSuggestion] = [
        .init(
            label: "Water",
            trackerName: "Water Intake",
            instruction: "Track the water I drink",
            emoji: "💧",
            kind: .number,
            formats: [.goal, .number]
        ),
        .init(
            label: "Coffee",
            trackerName: "Cups of Coffee",
            instruction: "Track my coffee consumption",
            emoji: "☕️",
            kind: .number,
            formats: [.number, .binary]
        ),
        .init(
            label: "Chores",
            trackerName: "Chores Completed",
            instruction: "Track my chores accomplished",
            emoji: "🧽",
            kind: .binary,
            formats: [.binary, .duration, .choices]
        ),
        .init(
            label: "Mood",
            trackerName: "Daily Mood",
            instruction: "Track my daily mood",
            emoji: "😁",
            kind: .choices,
            formats: [.choices, .number]
        ),
        .init(
            label: "Meditation",
            trackerName: "Meditation Sessions",
            instruction: "Track my meditation sessions",
            emoji: "🧘",
            kind: .duration,
            formats: [.duration, .binary]
        ),
        .init(
            label: "Time Outside",
            trackerName: "Time Spent Outdoors",
            instruction: "Track the time I spend outdoors",
            emoji: "🌳",
            kind: .duration,
            formats: [.duration, .binary]
        ),
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
                .init(
                    label: "Time Outside",
                    trackerName: "Time Spent Outdoors",
                    instruction: "Track the time I spend outdoors",
                    emoji: "🌳",
                    kind: .duration,
                    formats: [.duration, .binary]
                ),
                .init(
                    label: "Practice",
                    trackerName: "Music Practice",
                    instruction: "Track my music practice",
                    emoji: "🎸",
                    kind: .duration
                ),
                .init(
                    label: "Reading",
                    instruction: "Track my reading time",
                    emoji: "📖",
                    kind: .duration
                ),
                .init(
                    label: "Focus Work",
                    instruction: "Track my focused work sessions",
                    emoji: "🧑‍💻",
                    kind: .duration
                ),
                .init(
                    label: "Gaming",
                    instruction: "Track my gaming session duration",
                    emoji: "🎮",
                    kind: .duration
                ),
            ]
        case .binary:
            [
                .init(
                    label: "Took Meds",
                    instruction: "Track if I took my meds",
                    emoji: "💊",
                    kind: .binary
                ),
                .init(
                    label: "Gym",
                    instruction: "Track if I went to the gym",
                    emoji: "🏋️",
                    kind: .binary
                ),
                .init(
                    label: "Ate Healthy",
                    instruction: "Track if I ate healthy",
                    emoji: "🥗",
                    kind: .binary
                ),
                .init(
                    label: "Flossed",
                    instruction: "Track if I flossed",
                    emoji: "🦷",
                    kind: .binary
                ),
                .init(
                    label: "No Alcohol",
                    instruction: "Track if I skipped alcohol",
                    emoji: "🍺",
                    chipEmoji: "🚫🍺",
                    kind: .binary
                ),
            ]
        case .choices:
            [
                .init(
                    label: "Mood",
                    instruction: "Track my daily mood",
                    emoji: "😁",
                    kind: .choices
                ),
                .init(
                    label: "Sleep Quality",
                    instruction: "Track how well I slept",
                    emoji: "😴",
                    kind: .choices
                ),
                .init(
                    label: "Social Contact",
                    instruction: "Track the people I see most",
                    emoji: "👥",
                    kind: .choices
                ),
                .init(
                    label: "Meal Type",
                    instruction: "Track what I ate",
                    emoji: "🍽️",
                    kind: .choices
                ),
                .init(
                    label: "Cravings",
                    instruction: "Track my food cravings",
                    emoji: "🍫",
                    kind: .choices
                ),
            ]
        case .date:
            [
                .init(
                    label: "Period",
                    instruction: "Track my period",
                    emoji: "🩸",
                    kind: .date
                ),
                .init(
                    label: "Haircut",
                    instruction: "Track when I get a haircut",
                    emoji: "💇",
                    kind: .date
                ),
                .init(
                    label: "Allergy",
                    instruction: "Track when my allergies flare up",
                    emoji: "🤧",
                    kind: .date
                ),
                .init(
                    label: "Watered Plants",
                    instruction: "Track when I water my plants",
                    emoji: "🪴",
                    kind: .date
                ),
                .init(
                    label: "Migraine",
                    instruction: "Track when my migraine episodes occur",
                    emoji: "🤕",
                    kind: .date
                ),
            ]
        case .goal:
            [
                .init(
                    label: "Water",
                    trackerName: "Glasses of Water",
                    instruction: "Track how many glasses of water I drink",
                    emoji: "💧",
                    kind: .goal
                ),
                .init(
                    label: "Pushups",
                    instruction: "Track my daily pushups",
                    emoji: "💪",
                    kind: .goal
                ),
                .init(
                    label: "Veggies",
                    trackerName: "Veggie Servings",
                    instruction: "Track my veggie servings",
                    emoji: "🥦",
                    kind: .goal
                ),
                .init(
                    label: "New Words",
                    instruction: "Track new words I learn",
                    emoji: "🗣️",
                    kind: .goal
                ),
                .init(
                    label: "Chores",
                    instruction: "Track chores completed",
                    emoji: "🧹",
                    kind: .goal
                ),
            ]
        case .number:
            [
                .init(
                    label: "Fuel Spend",
                    trackerName: "Fuel Cost",
                    instruction: "Track how much I spend on fuel",
                    emoji: "⛽️",
                    kind: .number
                ),
                .init(
                    label: "Waist",
                    instruction: "Track my waist measurement",
                    emoji: "📏",
                    kind: .number
                ),
                .init(
                    label: "Cigarettes",
                    instruction: "Track cigarettes smoked",
                    emoji: "🚬",
                    kind: .number
                ),
                .init(
                    label: "Coffee",
                    trackerName: "Cups of Coffee",
                    instruction: "Track my coffee consumption",
                    emoji: "☕️",
                    kind: .number
                ),
                .init(
                    label: "Pain",
                    trackerName: "Pain Level",
                    instruction: "Track my pain level",
                    emoji: "😖",
                    kind: .number
                ),
            ]
        }
    }
}
