//
//  NumberAiCompletion.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/06/2026.
//

import Foundation
import FoundationModels

@Generable(
    description: "A config to track bounded or open-ended numbers metric"
)
struct NumberAiCompletionSchema {
    @Guide(
        description: """
            An optional unit that defines this number metric. 
            E.g. 'kg', 'reps', 'mg'.
            Define it only when it make sense for the metric
            """
    )
    let unit: String?

    @Guide(
        description: "A realistic upper bound a user would log in this unit."
    )
    let typicalMax: Double

    @Guide(
        description: """
            Increment step natural to the unit. 
            It will be used as increment step for the UI stepper, 
            to help user log there value
            E.g. 1 for counts, 0.1 for precise weight, 0.5, 5, 10, 100...
            """
    )
    let granularity: Double

}

@Generable(
    description:
        "Distinct configs for number metric"
)
struct NumberAiCompletionListSchema {
    @Guide(
        description: "Distinct constraint to track this number metric",
        .count(1...3)
    )
    let constraints: [NumberAiCompletionSchema]

    @Guide(description: "A single emoji that fit the metric")
    let emoji: String

    @Guide(
        description:
            "Does this metric cumulate throughout the day or is a snapshot ?"
    )
    let isCumulative: Bool
    
    @Guide(
        description:"""
            Define if the metric is bounded or open-ended.
            It will be use to know if the typicalMax is soft or hard
            """
    )
    let isBounded: Bool
}

struct NumberAiCompletion {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func generate(for instruction: String) async throws
        -> NumberAiCompletionListSchema
    {
        try await AiSchemaCompletion(
            userPrompt: AIAutoCompleteInstruction.userPrompt(
                for: instruction,
                locale: locale
            ),
            systemPrompt: AIAutoCompleteInstruction.systemPrompt
        )
        .generate(as: NumberAiCompletionListSchema.self)
    }
}
