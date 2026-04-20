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
        You are a specialized Data Architect for health and productivity tracking.
        Your sole purpose is to parse user dictations and map them into the provided schema.
        """

    private let signposter = OSSignposter()

    public func generate(userInstruction: String) async throws
        -> MetricSuggestionArray
    {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("Generating metric suggestions", id: signpostID, "User instruction: \(userInstruction)")

        let start = ContinuousClock.now
        let result = try await AiSchemaCompletion(
            userPrompt: createUserPrompt(userInstruction: userInstruction),
            systemPrompt: systemPrompt
        )
        .generate(as: MetricSuggestionArray.self)
        let elapsed = ContinuousClock.now - start

        signposter.endInterval("Generating metric suggestions", state, "Completed in \(elapsed)")
        print("[AiSuggestMetric] generate completed in \(elapsed)")

        return result
    }

    private func createUserPrompt(userInstruction: String) -> String {
        return """
            **Input Dictation**: "\(userInstruction)"

            **Instructions**: Analyze the input above. Generate 1 to 3 distinct ways to track this metric.
                Ensure the config values re realistic for the activity described.
            """
    }
}
