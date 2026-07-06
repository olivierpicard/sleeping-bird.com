//
//  IntentAiCompletion+Fake.swift
//  ArperBird
//
//  DEBUG-only fake intent completion for previews — no Firebase AI call.
//

#if DEBUG
import Foundation

extension IntentAiCompletion {
    /// Returns a canned intent without hitting the AI backend. Mirrors
    /// `generate(for:)` so previews can drive the same code paths.
    func generateFake(for instruction: String) async throws -> IntentCompletion {
        IntentCompletion(
            title: instruction,
            emoji: "📊",
            formats: [.number, .binary]
        )
    }
}
#endif
