//
//  GoalAiCompletion.swift
//  ArperBird
//
//  Created by Olivier Picard on 23/06/2026.
//

import Foundation
import FoundationModels

@Generable(description: "A goal metric configuration")
struct GoalAiCompletionSchema {
    @Guide(description: "The unit that define this goal metric")
    let unit: String
    @Guide(description: "The goal to reach daily")
    let dailyGoal: Double
    @Guide(description: "Incremental step used by UI to ease user log")
    let granularity: Double
}

@Generable(description: "A list of goal metric configurations")
struct GoalAiCompletionListSchema {
    @Guide(
        description: "Distinct ways to track this goal metric",
        .count(1...3)
    )
    let goals: [GoalAiCompletionSchema]
    
    @Guide(description: "A single emoji that fit the metric")
    let emoji: String
}

struct GoalAiCompletion {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func generate(for instruction: String) async throws
        -> GoalAiCompletionListSchema
    {
        try await AiSchemaCompletion(
            userPrompt: AIAutoCompleteInstruction.userPrompt(
                for: instruction,
                locale: locale
            ),
            systemPrompt: AIAutoCompleteInstruction.systemPrompt
        )
        .generate(as: GoalAiCompletionListSchema.self)
    }
}
