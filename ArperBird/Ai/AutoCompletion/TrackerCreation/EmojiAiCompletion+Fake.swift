//
//  EmojiAiCompletion+Fake.swift
//  ArperBird
//
//  DEBUG-only fake emoji completion for previews — no Firebase AI call.
//

import Foundation

extension EmojiAiCompletion {
    /// Returns a canned emoji without hitting the AI backend. Mirrors
    /// `generate(for:)` so previews can drive the same code paths.
    func generateFake(for instruction: String) async throws
        -> EmojiAiCompletionSchema
    {
        EmojiAiCompletionSchema(emoji: "💪")
    }
}
