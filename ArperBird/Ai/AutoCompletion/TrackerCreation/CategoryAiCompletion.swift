//
//  CategoryAiCompletion.swift
//  ArperBird
//
//  Created by Olivier Picard on 23/06/2026.
//

import Foundation
import FoundationModels

@Generable(
    description:
        "A config for a metric tracked by selecting from a fixed set of categories"
)
struct CategoryAiCompletionSchema {
    @Guide(
        description:
            "The possible values the user picks from when logging this metric. E.g. for a mood tracker: Happy, Neutral, Sad, Anxious.",
        .minimumCount(CategoryLimits.min),
        .maximumCount(CategoryLimits.max)
    )
    let categories: [String]

    @Guide(
        description:
            "True if the user may select several categories in a single entry (e.g. symptoms felt today); false if exactly one applies (e.g. today's mood)."
    )
    let allowsMultipleSelection: Bool

    @Guide(
        description:
            "A single emoji that represents the metric. Emoji only, no text."
    )
    let emoji: String
}

struct CategoryAiCompletion {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func generate(for instruction: String) async throws
        -> CategoryAiCompletionSchema
    {
        let result = try await AiSchemaCompletion(
            userPrompt: AIAutoCompleteInstruction.userPrompt(
                for: instruction,
                locale: locale
            ),
            systemPrompt: AIAutoCompleteInstruction.systemPrompt
        )
        .generate(as: CategoryAiCompletionSchema.self)

        return result
    }
}
