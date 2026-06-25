//
//  DurationAiCompletion+Fake.swift
//  ArperBird
//
//  DEBUG-only fake duration completion for previews — no Firebase AI call.
//

#if DEBUG
import Foundation

extension DurationAiCompletion {
    /// Returns a canned duration config without hitting the AI backend.
    /// Mirrors `generate(for:)` so previews can drive the same code paths.
    func generateFake(for instruction: String) async throws
        -> DurationAiCompletionSchema
    {
        DurationAiCompletionSchema(maxInSeconds: 2 * 60 * 60, emoji: "🏋️")
    }
}
#endif
