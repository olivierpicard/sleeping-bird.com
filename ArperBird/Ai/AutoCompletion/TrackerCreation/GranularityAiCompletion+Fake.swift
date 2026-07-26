//
//  GranularityAiCompletion+Fake.swift
//  ArperBird
//
//  DEBUG-only fake granularity completion for previews — no Firebase AI call.
//

#if DEBUG
import Foundation

extension GranularityAiCompletion {
    /// Returns a canned step without hitting the AI backend. Mirrors
    /// `generate(for:)` so previews can drive the same code paths.
    func generateFake(for instruction: String) async throws
        -> GranularityAiCompletionSchema
    {
        GranularityAiCompletionSchema(granularity: 0.5)
    }
}
#endif
