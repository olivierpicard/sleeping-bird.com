//
//  MetricSchema.swift
//  SleepingBird
//
//  Created by Olivier Picard on 20/04/2026.
//

import FoundationModels

@Generable()
public struct MetricSuggestionArray {
    @Guide(
        description: "A list of suggested metrics",
        .minimumCount(1),
        .maximumCount(3)
    )
    let suggestions: [MetricSuggestion]
}

@Generable(description: "A metric description and configuration")
public struct MetricSuggestion {
    @Guide(
        description:
            "Concise title name. E.g., 'Deep Sleep Duration'"
    )
    let name: String

    @Guide(
        description: "Confidence score. 1.0 means a clear match.",
        .range(0...1)
    )
    let fitPercentage: Double

    @Guide(description: "The config that best suite the metric need")
    let config: MetricConfig

}

@Generable(description: "Types of metrics that can be tracked")
public enum MetricConfig {
    case number(NumberConfig)
    case categorySingleChoice(CategoryConfig)
    case categoryMultipleChoice(CategoryConfig)
    case binary(BinaryConfig)
    case datetime(DatetimeConfig)
    case duration(DurationConfig)

}

@Generable(description: "Match with a number metric type")
public struct NumberConfig: Codable {
    let min, max: Double

    @Guide(
        description:
            "Increment step natural to the metric. E.g., 1 for counts, 0.1 for precise weight, or 0.5, 0.01, 5, 10, ... for other metrics"
    )
    let granularity: Double

    @Guide(
        description:
            "Display unit. E.g., 'kg', 'steps', 'kcal'. Unit must be natural and fit naturally don't force it"
    )
    let unit: String?

    @Guide(
        description:
            "Optional target value. Only define it when user say it explicitly"
    )
    let goal: Double?
}

@Generable(description: "Match with a category metric type")
public struct CategoryConfig: Codable {
    @Guide(
        description: "All possible values for this metric",
        .minimumCount(2),
        .maximumCount(15)
    )
    let labels: [String]
}

@Generable(description: "Match a binary metric type")
public struct BinaryConfig: Codable {
    let trueLabel: String
    let falseLabel: String
}

@Generable(description: "Match a datetime metric type")
public struct DatetimeConfig {}

@Generable(description: "Match a duration metric type")
public struct DurationConfig {
    @Guide(
        description: "Floor smallest granularity that best suite the metric",
        .anyOf(["ms", "s", "m", "h"])
    )
    let granularity: String

    @Guide(
        description: "Expected max duration for this metric",
        .range(0...Int.max)
    )
    let maxInSeconds: Int
}
