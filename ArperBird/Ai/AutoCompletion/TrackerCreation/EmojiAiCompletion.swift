//
//  EmojiAiCompletion.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/06/2026.
//

import Foundation
import FoundationModels

@Generable(description: "A single emoji that represents a metric")
struct EmojiAiCompletionSchema {
    @Guide(description: "A single emoji that fit the metric")
    let emoji: String
}

/// Picks a matching emoji for a tracker from its name alone. Deliberately the
/// smallest completion in the family — the binary, date, and duration paths need
/// nothing from the AI *but* an emoji, so they share this instead of carrying a
/// type-specific schema.
struct EmojiAiCompletion {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func generate(for instruction: String) async throws
        -> EmojiAiCompletionSchema
    {
        let emoji = try await AiSchemaCompletion(
            userPrompt: AIAutoCompleteInstruction.userPrompt(
                for: instruction,
                locale: locale
            ),
            systemPrompt: AIAutoCompleteInstruction.systemPrompt
        )
        .generate(as: EmojiAiCompletionSchema.self)

        return emoji
    }
}
