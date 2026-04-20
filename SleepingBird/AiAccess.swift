//
//  AiAccess.swift
//  SleepingBird
//
//  Created by Olivier Picard on 19/04/2026.
//

import FirebaseAILogic
import Foundation

public struct AiAccess {
    public func suggestMetric(for userRequest: String) async throws
        -> [MetricSuggestion]
    {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())

        let config = GenerationConfig(

            responseMIMEType: "application/json",
            responseSchema: .array(
                items: MetricSuggestion.schema,
                description:
                    "A list of 1 to 3 tracking configurations based on the user's intent.",
                minItems: 1,
                maxItems: 3
            ),
            thinkingConfig: ThinkingConfig(thinkingLevel: .minimal),
            
        )
        let systemPrompt = """
              You are a specialized Data Architect for health and productivity tracking. Your sole purpose is to parse user dictations and map them into the provided JSON schema.

            ### Mapping Logic:
            1. **Intelligence**: Translate vague intent into specific constraints.
               - If a user says "Scale of 1 to 10", set 'min: 1', 'max: 10', 'granularity: 1', 'type: "number"'.
               - If a user says "Did I...", use 'type: "binary"'.
               - ...


            ### Constraints:
            - Never infer a goal automatically. Fill the goal only when it is explicitly defined by the user
            - For duration respect the 'granularity' (ms, s, m, h) as the "floor" for input.
            
            """

        let model = ai.generativeModel(
            modelName: "gemini-3-flash-preview",
            generationConfig: config,
            systemInstruction: ModelContent(role: "system", parts: systemPrompt)
        )

        let prompt = """
            **Input Dictation**: "\(userRequest)"

            **Instructions**: Analyze the input above. Generate 1 to 3 distinct ways to track this metric. 
                Ensure the config values re realistic for the activity described.
            """

                    
        let response = try await model.generateContent(prompt)

        guard let text = response.text,
            let data = text.data(using: String.Encoding.utf8)
        else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([MetricSuggestion].self, from: data)
    }

}

public struct MetricSuggestion: Codable {
    let name: String
    let fitPercentage: Double
    let config: MetricConfig

    static var schema: Schema {
        .object(
            properties: [
                "name": .string(
                    description:
                        "Concise, title-cased name. E.g., 'Daily Hydration', 'Deep Sleep Duration', 'Anxiety Level'."
                ),
                "fitPercentage": .double(
                    description:
                        "Confidence score [0.0 to 1.0]. Use 1.0 only if the user's intent is unambiguous (e.g., 'Track steps'). Use values < 1.0 to offer multiple perspectives for vague intents.",
                    minimum: 0,
                    maximum: 1
                ),
                "config": .anyOf(schemas: [
                    // number
                    .object(
                        properties: [
                            "type": .string(
                                description: "Discriminator",
                                format: .custom("number")
                            ),
                            "min": .double(
                                description:
                                    "Lower bound. E.g., 0 for weight, 1 for a 1-10 scale.",
                                minimum: 0
                            ),
                            "max": .double(
                                description:
                                    "Upper bound. E.g., 500 daily carbs, 10 for pain levels.",
                                minimum: 0
                            ),
                            "granularity": .double(
                                description:
                                    "Increment step. E.g., 1 for counts, 0.1 for precise weight, 0.5, 0.01, 5, 10, ...",
                                minimum: 0
                            ),
                            "unit": .string(
                                description:
                                    "Display unit. E.g., 'kg', 'steps', 'kcal'. Unit must be natural and fit naturally don't force it"
                            ),
                            "goal": .double(
                                description:
                                    "Optional target value. E.g., 2000 calories.",
                                minimum: 0
                            ),
                        ],
                        optionalProperties: ["unit", "goal"],
                        propertyOrdering: [
                            "type", "min", "max", "granularity", "unit", "goal",
                        ],
                        description:
                            "Track a numeric value within a defined range. E.g., weight, calories, pain level, steps."
                    ),
                    // categorySingle
                    .object(
                        properties: [
                            "type": .string(
                                description: "Discriminator",
                                format: .custom("categorySingle")
                            ),
                            "labels": .array(
                                items: .string(description: "A category label"),
                                description:
                                    "Named options to choose from. E.g., ['Great', 'Good', 'Meh', 'Bad'].",
                                minItems: 2,
                                maxItems: 15
                            ),
                        ],
                        propertyOrdering: ["type", "labels"],
                        description:
                            "Track exactly one choice from a fixed list. E.g., mood, workout type."
                    ),
                    // categoryMultiple
                    .object(
                        properties: [
                            "type": .string(
                                description: "Discriminator",
                                format: .custom("categoryMultiple")
                            ),
                            "labels": .array(
                                items: .string(description: "A category label"),
                                description:
                                    "Named options to choose from. E.g., ['Headache', 'Fatigue', 'Nausea'].",
                                minItems: 2,
                                maxItems: 15
                            ),
                        ],
                        propertyOrdering: ["type", "labels"],
                        description:
                            "Track one or more choices from a fixed list. E.g., symptoms, activities."
                    ),
                    // binary
                    .object(
                        properties: [
                            "type": .string(
                                description: "Discriminator",
                                format: .custom("binary")
                            ),
                            "trueLabel": .string(
                                description:
                                    "E.g., 'Did it', 'Yes', 'Took Meds'."
                            ),
                            "falseLabel": .string(
                                description: "E.g., 'Missed', 'No', 'Sober'."
                            ),
                        ],
                        propertyOrdering: ["type", "trueLabel", "falseLabel"],
                        description:
                            "Track a yes/no habit or event. E.g., took medication, exercised today."
                    ),
                    // datetime
                    .object(
                        properties: [
                            "type": .string(
                                description: "Discriminator",
                                format: .custom("datetime")
                            )
                        ],
                        propertyOrdering: ["type"],
                        description:
                            "Track a point in time. E.g., bedtime, appointment."
                    ),
                    // duration
                    .object(
                        properties: [
                            "type": .string(
                                description: "Discriminator",
                                format: .custom("duration")
                            ),
                            "granularity": .string(
                                description:
                                    "Smallest unit of input allowed. 'ms', 's', 'm', or 'h'. E.g., 'm' limits to minutes/hours."
                            ),
                            "maxInSeconds": .double(
                                description:
                                    "Expected max duration in seconds. E.g., 7200 for a 2h workout.",
                                minimum: 0
                            ),
                        ],
                        propertyOrdering: [
                            "type", "granularity", "maxInSeconds",
                        ],
                        description:
                            "Track an elapsed time. E.g., workout duration, sleep, meditation."
                    ),
                ]),
            ],
            propertyOrdering: ["name", "fitPercentage", "config"],
            description: "A suggested metric configuration"
        )
    }
}

public enum MetricConfig: Codable {
    case number(NumberConfig)
    case categorySingle(CategoryConfig)
    case categoryMultiple(CategoryConfig)
    case binary(BinaryConfig)
    case datetime(DatetimeConfig)
    case duration(DurationConfig)

    private enum TypeKey: String, CodingKey { case type }
    private enum TypeValue: String, Codable {
        case number, categorySingle, categoryMultiple, binary, datetime, duration
    }

    public func encode(to encoder: Encoder) throws {
        var typeContainer = encoder.container(keyedBy: TypeKey.self)
        switch self {
        case .number(let c):
            try typeContainer.encode(TypeValue.number, forKey: .type)
            try c.encode(to: encoder)
        case .categorySingle(let c):
            try typeContainer.encode(TypeValue.categorySingle, forKey: .type)
            try c.encode(to: encoder)
        case .categoryMultiple(let c):
            try typeContainer.encode(TypeValue.categoryMultiple, forKey: .type)
            try c.encode(to: encoder)
        case .binary(let c):
            try typeContainer.encode(TypeValue.binary, forKey: .type)
            try c.encode(to: encoder)
        case .datetime(let c):
            try typeContainer.encode(TypeValue.datetime, forKey: .type)
            try c.encode(to: encoder)
        case .duration(let c):
            try typeContainer.encode(TypeValue.duration, forKey: .type)
            try c.encode(to: encoder)
        }
    }

    public init(from decoder: Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: TypeKey.self)
        let typeValue = try typeContainer.decode(TypeValue.self, forKey: .type)
        switch typeValue {
        case .number: self = .number(try NumberConfig(from: decoder))
        case .categorySingle: self = .categorySingle(try CategoryConfig(from: decoder))
        case .categoryMultiple: self = .categoryMultiple(try CategoryConfig(from: decoder))
        case .binary: self = .binary(try BinaryConfig(from: decoder))
        case .datetime: self = .datetime(try DatetimeConfig(from: decoder))
        case .duration: self = .duration(try DurationConfig(from: decoder))
        }
    }
}

public struct NumberConfig: Codable {
    let min, max, granularity: Double
    let unit: String?
    let goal: Double?
}

public struct CategoryConfig: Codable {
    let labels: [String]
}

public struct BinaryConfig: Codable {
    let trueLabel: String
    let falseLabel: String
}

public struct DatetimeConfig: Codable {}

public struct DurationConfig: Codable {
    let granularity: String
    let maxInSeconds: Double
}
