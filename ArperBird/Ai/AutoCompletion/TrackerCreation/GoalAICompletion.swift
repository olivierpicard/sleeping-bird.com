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
    @Guide(description: "A single emoji that fit the metric")
    let emoji: String
}

@Generable(description: "A list of goal metric configurations")
struct GoalAiCompletionListSchema {
    @Guide(
        description: "Distinct ways to track this goal metric",
        .count(1...3)
    )
    let goals: [GoalAiCompletionSchema]
}

struct GoalAiCompletion {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func generate(for instruction: String) async throws
        -> [GoalAiCompletionSchema]
    {
        let goals = try await AiSchemaCompletion(
            userPrompt: AIAutoCompleteInstruction.userPrompt(
                for: instruction,
                locale: locale
            ),
            systemPrompt: AIAutoCompleteInstruction.systemPrompt
        )
        .generate(as: GoalAiCompletionListSchema.self)
        .goals
        
        return goals
    }
}
