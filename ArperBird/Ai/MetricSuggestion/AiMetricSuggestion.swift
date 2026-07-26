//
//  AiMetricSuggestion.swift
//  ArperBird
//
//  Created by Olivier Picard on 20/04/2026.
//

import Foundation

struct AiMetricSuggestion {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    private let systemPrompt = """
        You are a specialized Data Architect for user metric tracking.
        Your sole purpose is to map user instruction into the provided schema.
        Use the most typical configuration for the metric requested.
        Make the configuration reflect the user local region
        """

    private func createUserPrompt(userInstruction: String) -> String {
        return """
            **Input Dictation**: "\(userInstruction)"
            **User Locale**: "\(locale.identifier)"
            **Instructions**: Analyze the input above. 
                Generate the most probable and pragmatic way to track this metric.
                The metric should match the user intent.
                Use the most natural and common way of tracking this.
                Ensure the config values are realistic for the activity described.
                Use the user language and the region to improve the metric description & definition
            """
    }

    func generate(userInstruction: String) async throws -> MetricSchema {
        let result = try await AiSchemaCompletion(
            userPrompt: createUserPrompt(userInstruction: userInstruction),
            systemPrompt: systemPrompt
        )
        .generate(as: MetricSchema.self)

        return result
    }
}
