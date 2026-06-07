//
//  AiAccess.swift
//  SleepingBird
//
//  Created by Olivier Picard on 19/04/2026.
//

import FirebaseAILogic
import Foundation
import FoundationModels

struct AiSchemaCompletion {
    let userPrompt: String
    let systemPrompt: String?

    init(userPrompt: String, systemPrompt: String? = nil) {
        self.userPrompt = userPrompt
        self.systemPrompt = systemPrompt
    }

    func generate<T: Generable>(as schema: T.Type = T.self) async throws
        -> T
    {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        let session = ai.generativeModelSession(
            model: "gemini-3-flash-preview",
            instructions: systemPrompt
        )
        let result = try await session.respond(
            to: userPrompt,
            generating: schema,
            options: GenerationConfig(
                thinkingConfig: ThinkingConfig(thinkingLevel: .medium)
            )
        )

        return result.content
    }
}



