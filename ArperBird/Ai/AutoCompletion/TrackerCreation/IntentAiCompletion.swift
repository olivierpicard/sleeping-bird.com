//
//  IntentAiCompletion.swift
//  ArperBird
//
//  Created by Olivier Picard on 05/07/2026.
//

import Foundation
import FoundationModels

@Generable(description: "A minimal logging format for a tracker")
enum IntentFormatType: String {
    case number
    case duration
    case binary
    case goal
    case choices
    case date
}

extension IntentFormatType {
    /// The tracker kind this format belongs to — used to tint the card, in
    /// both `TrackerIntentView` and the seeded `TrackerFormatPickerView`
    /// entry.
    var kind: TrackerKind {
        switch self {
        case .number: .number
        case .duration: .duration
        case .binary: .binary
        case .goal: .goal
        case .choices: .choices
        case .date: .date
        }
    }
}

@Generable(description: "Interpreted intent for a tracker described in free text")
struct IntentCompletion {
    @Guide(description: "A short human title for the tracker, e.g. 'Coffee', 'Reading time'")
    let title: String

    @Guide(description: "A single emoji that represents the tracker")
    let emoji: String

    @Guide(
        description: "The ways this tracker can be logged, best-fit first",
        .count(1...3)
    )
    let formats: [IntentFormatType]
}

/// Interprets whatever the user typed in the intent field into a titled,
/// emoji'd tracker plus the handful of logging formats that best fit it —
/// the free-text counterpart to the per-facet completions, returning a whole
/// intent rather than a single facet. Mirrors `EmojiAiCompletion`.
struct IntentAiCompletion {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func generate(for instruction: String) async throws -> IntentCompletion {
        try await AiSchemaCompletion(
            userPrompt: AIAutoCompleteInstruction.userPrompt(
                for: instruction,
                locale: locale
            ),
            systemPrompt: AIAutoCompleteInstruction.systemPrompt
        )
        .generate(as: IntentCompletion.self)
    }
}
