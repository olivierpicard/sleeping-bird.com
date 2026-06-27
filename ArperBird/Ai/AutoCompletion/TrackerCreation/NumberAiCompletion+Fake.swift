//
//  NumberAiCompletion+Fake.swift
//  ArperBird
//
//  DEBUG-only fake number completion for previews — no Firebase AI call.
//

#if DEBUG
    import Foundation

    extension NumberAiCompletion {
        /// Returns canned number units without hitting the AI backend.
        /// Mirrors `generate(for:)` so previews can drive the same code paths.
        func generateFake(for instruction: String) async throws
            -> NumberAiCompletionListSchema
        {
            NumberAiCompletionListSchema(
                constraints: [
                    NumberAiCompletionSchema(
                        unit: "kg",
                        typicalMax: 120,
                        granularity: 0.1
                    ),
                    NumberAiCompletionSchema(
                        unit: "lb",
                        typicalMax: 260,
                        granularity: 0.5
                    ),
                ],
                emoji: "⚖️",
                isCumulative: false,
                isBounded: false
            )
        }
    }
#endif
