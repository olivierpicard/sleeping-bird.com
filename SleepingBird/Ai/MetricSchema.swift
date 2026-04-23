//
//  MetricSchema.swift
//  SleepingBird
//
//  Created by Olivier Picard on 20/04/2026.
//

import FoundationModels

// MARK: -Metric Suggesion

@Generable()
public struct MetricSuggestionArray {
    @Guide(
        description: "A list of suggested metrics",
        .minimumCount(1),
        .maximumCount(4)
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
    
    @Guide(description: "A single emoji that fit the metric")
    let emoji: String

    @Guide(
        description: "Confidence score. 1.0 means a clear match.",
        .range(0...1)
    )
    let fitPercentage: Double

    @Guide(description: "The config that best suite the metric need")
    let config: MetricConfig

    let Visual: MetricVisual
}

// MARK: -Metric Type Config

@Generable(description: "Types of metrics that can be tracked")
public enum MetricConfig {
    case number(NumberConfig)
    case categorySingleChoice(CategoryConfig)
    case categoryMultipleChoice(CategoryConfig)
    case binary(BinaryConfig)
    case datetime
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

    @Guide(description: "Defines how the number behaves over time")
    let behavior: MetricBehavior
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
    
    @Guide(description: "Defines how the datetime behaves over time")
    let behavior: MetricBehavior
}

// MARK: -Metric Behaviour

@Generable(
    description: """
            How the metric behaves over time. 
            Cumulative: values that make sense when sum up. E.g., Water intake, steps counter, time spend...
            Snapshot: measurements that loose sense when cumulated over time. E.g., temperature, how long it take... 
        """
)
public enum MetricBehavior: String, Codable {
    case cumulative
    case snapshot
}

// MARK: -Metric visual

@Generable()
public struct MetricVisual {
    let chart: ChartType
    let aggregation: AggregationConfig
}

@Generable()
public enum ChartType: String, Codable {
    case line  // Best for continuous trends over time (Weight, duration)
    case bar  // Best for discrete, summed, or counted data (Calories, steps)
    case pie  // Best for proportions (Categories)
    case heatmap  // GitHub-style contribution graph (Best for Binary habits or frequency)
    case gauge  // Good if the metric has a specific daily `goal` limit
}

// MARK: - Metric Groupping

@Generable(description: "Rules for grouping multiple data points over time.")
public struct AggregationConfig: Codable {

    @Guide(description: "How data should be groupped (or not) by time.")
    let bucket: TemporalBucket?

    let method: AggregationMethod
}

@Generable()
public enum TemporalBucket: String, Codable {
    case hourly
    case daily
    case weekly
    case monthly
    case yearly
}

@Generable()
public enum AggregationMethod: Codable {
    case numerical(NumericMethod)
    case categorical(CategoricalMethod)
}

@Generable()
public enum NumericMethod: String, Codable {
    case sum  // e.g., Water intake
    case average  // e.g., Heart rate, Weight
    case min  // e.g., Lowest temperature
    case max  // e.g., Top speed
    case latest  // e.g., Current balance
}

@Generable(
    description: """
        count: total number of entries
        mostFrequent: 
        """
)
public enum CategoricalMethod: String, Codable {
    case count  // Total number of entries
    case mostFrequent  // The "Mode" (e.g., most frequent mood)
    case distribution  // Percentage breakdown (required for Pie charts)
    case uniqueCount  // How many different categories were logged
}
