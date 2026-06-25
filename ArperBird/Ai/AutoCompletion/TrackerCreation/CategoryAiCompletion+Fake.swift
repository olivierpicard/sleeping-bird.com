//
//  CategoryAiCompletion+Fake.swift
//  ArperBird
//
//  DEBUG-only fake category completion for previews — no Firebase AI call.
//

#if DEBUG
import Foundation

extension CategoryAiCompletion {
    /// Returns a canned category config without hitting the AI backend.
    /// Mirrors `generate(for:)` so previews can drive the same code paths.
    func generateFake(for instruction: String) async throws
        -> CategoryAiCompletionSchema
    {
        CategoryAiCompletionSchema(
            categories: ["Happy", "Calm", "Tired", "Anxious", "Sad"],
            allowsMultipleSelection: false,
            emoji: "😊"
        )
    }
}
#endif
