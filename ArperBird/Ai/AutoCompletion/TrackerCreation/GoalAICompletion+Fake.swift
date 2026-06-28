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
        -> GoalAiCompletionListSchema
    {
        GoalAiCompletionListSchema(
            goals: [
                GoalAiCompletionSchema(unit: "glasses", dailyGoal: 8, granularity: 1),
                GoalAiCompletionSchema(unit: "ml", dailyGoal: 2000, granularity: 100),
                GoalAiCompletionSchema(unit: "liters", dailyGoal: 2, granularity: 0.5),
            ],
            emoji: "💧"
        )
    }
}
#endif
