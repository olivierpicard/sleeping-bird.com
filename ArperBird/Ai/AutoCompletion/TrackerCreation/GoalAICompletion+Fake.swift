//
//  GoalAICompletion+Fake.swift
//  ArperBird
//
//  DEBUG-only fake goal completion for previews — no Firebase AI call.
//

#if DEBUG
import Foundation

extension GoalAiCompletion {
    /// Returns canned goal suggestions without hitting the AI backend.
    /// Mirrors `generate(for:)` so previews can drive the same code paths.
    func generateFake(for instruction: String) async throws
        -> [GoalAiCompletionSchema]
    {
        [
            GoalAiCompletionSchema(unit: "glasses", dailyGoal: 8, emoji: "💧"),
            GoalAiCompletionSchema(unit: "ml", dailyGoal: 2000, emoji: "🥤"),
            GoalAiCompletionSchema(unit: "liters", dailyGoal: 2, emoji: "🚰"),
        ]
    }
}
#endif
