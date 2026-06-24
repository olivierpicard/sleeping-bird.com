//
//  AIAutoCompleteInstruction.swift
//  ArperBird
//
//  Created by Olivier Picard on 23/06/2026.
//

import Foundation

enum AIAutoCompleteInstruction {
    static let systemPrompt = """
        You are a specialized Data Architect for user metric tracking.
        Your sole purpose is to map user instruction into the provided schema.
        Use the most typical configuration for the metric requested.
        Make the configuration reflect the user local region
        """

    static func userPrompt(for instruction: String, locale: Locale = .current)
        -> String
    {
        """
        **Metric Info**: "\(instruction)"
        **User Locale**: "\(locale.identifier)"
        **Instructions**: Analyze the input above.
            Generate a list of most probable and pragmatic ways to track this metric.
            The metric should match the metric infot.
            Use the most natural and common way of tracking this.
            Get the most clue from the tracker name
            Ensure the config values are realistic for the activity described.
            Use the user language and the region to improve the metric description & definition
        """
    }
}
 
