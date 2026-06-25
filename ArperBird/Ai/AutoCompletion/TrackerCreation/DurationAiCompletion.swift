//
//  DurationAiCompletion.swift
//  ArperBird
//
//  Created by Olivier Picard on 23/06/2026.
//

import Foundation
import FoundationModels

@Generable(description: "A config for metric that measure a duration")
struct DurationAiCompletionSchema {
    @Guide(
        description: "Expected max duration for this metric",
        .range(0...Int.max)
    )
    let maxInSeconds: Int

    @Guide(description: "A single emoji that fit the metric")
    let emoji: String
}

struct DurationAiCompletion {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func generate(for instruction: String) async throws
        -> DurationAiCompletionSchema
    {
        let duration = try await AiSchemaCompletion(
            userPrompt: AIAutoCompleteInstruction.userPrompt(
                for: instruction,
                locale: locale
            ),
            systemPrompt: AIAutoCompleteInstruction.systemPrompt
        )
        .generate(as: DurationAiCompletionSchema.self)

        return duration
    }
}
