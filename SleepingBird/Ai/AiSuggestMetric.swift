//
//  AiSuggestMetric.swift
//  SleepingBird
//
//  Created by Olivier Picard on 20/04/2026.
//

import Foundation
import os

public struct AiSuggestMetric {
    private let systemPrompt = """
        You are a specialized Data Architect for user metric tracking.
        Your sole purpose is to map user instruction into the provided schema.
        Use the most typical configuration for the metric requested.
        """

    private func createUserPrompt(userInstruction: String) -> String {
        return """
            **Input Dictation**: "\(userInstruction)"

            **Instructions**: Analyze the input above. Generate 1 to 3 distinct ways to track this metric.
                Ensure the config values re realistic for the activity described.
            """
    }

    private let signposter = OSSignposter()

    public func generate(userInstruction: String) async throws
        -> MetricSuggestion
    {
        let start = ContinuousClock.now
        let result = try await AiSchemaCompletion(
            userPrompt: createUserPrompt(userInstruction: userInstruction),
            systemPrompt: systemPrompt
        )
            .generate(as: MetricSuggestion.self)
        let elapsed = ContinuousClock.now - start

        print("[AiSuggestMetric] generate completed in \(elapsed)")

        return result
    }
}
