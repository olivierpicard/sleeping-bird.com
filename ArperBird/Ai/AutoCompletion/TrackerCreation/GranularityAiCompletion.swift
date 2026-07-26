//
//  GranularityAiCompletion.swift
//  ArperBird
//
//  Created by Olivier Picard on 28/06/2026.
//

import Foundation
import FoundationModels

@Generable(description: "The natural step between entries for a metric")
struct GranularityAiCompletionSchema {
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

/// Picks a sensible step between entries for a tracker from its name and unit.
/// The goal path's unit suggestions carry a daily target but no step, so a unit
/// the user typed themselves has nothing to anchor it — this fills that gap.
/// A single-facet completion in the family, mirroring `EmojiAiCompletion`.
struct GranularityAiCompletion {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func generate(for instruction: String) async throws
        -> GranularityAiCompletionSchema
    {
        try await AiSchemaCompletion(
            userPrompt: AIAutoCompleteInstruction.userPrompt(
                for: instruction,
                locale: locale
            ),
            systemPrompt: AIAutoCompleteInstruction.systemPrompt
        )
        .generate(as: GranularityAiCompletionSchema.self)
    }
}
