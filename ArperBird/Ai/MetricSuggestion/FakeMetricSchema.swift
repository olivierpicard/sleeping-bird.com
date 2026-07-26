//
//  MockMetricSchema.swift
//  ArperBird
//
//  Created by Olivier Picard on 20/04/2026.
//

import Foundation

    extension MetricSchema {
        enum Fake {
            static func number(
                title: String = "Daily Steps",
                emoji: String = "👣",
                unit: String? = "steps",
                min: Double = 0,
                max: Double = 50_000,
                granularity: Double = 100,
                goal: Double? = 10_000,
                behavior: MetricBehavior = .cumulative,
                chart: ChartType = .bar,
                bucket: TemporalBucket? = .daily,
                method: AggregationMethod = .numerical(.sum)
            ) -> MetricSchema {
                MetricSchema(
                    name: title,
                    emoji: emoji,
                    fitPercentage: 0.95,
                    config: .number(
                        NumberConfig(
                            min: min,
                            max: max,
                            granularity: granularity,
                            unit: unit,
                            goal: goal,
                            behavior: behavior
                        )
                    ),
                    visual: MetricVisual(
                        chart: chart,
                        aggregation: AggregationConfig(bucket: bucket, method: method)
                    )
                )
            }

            static func categorySingle(
                title: String = "Mood",
                emoji: String = "😊",
                // Generic on purpose: this default is what renders in
                // format-picker/intent previews before any real topic is known
                // (see TrackerIntentView/TrackerFormatPickerView), so it must
                // never look like real data for an unrelated tracker.
                labels: [String] = (1...5).map {
                    String(localized: "Example \($0)")
                },
                chart: ChartType = .pie,
                bucket: TemporalBucket? = .daily,
                method: AggregationMethod = .categorical(.mostFrequent)
            ) -> MetricSchema {
                MetricSchema(
                    name: title,
                    emoji: emoji,
                    fitPercentage: 0.88,
                    config: .categorySingleChoice(
                        CategoryConfig(labels: labels)
                    ),
                    visual: MetricVisual(
                        chart: chart,
                        aggregation: AggregationConfig(bucket: bucket, method: method)
                    )
                )
            }

            static func categoryMultiple(
                title: String = "Symptoms",
                emoji: String = "🤒",
                labels: [String] = [
                    "Headache", "Fatigue", "Nausea", "Back pain", "Anxiety",
                ],
                chart: ChartType = .bar,
                bucket: TemporalBucket? = .daily,
                method: AggregationMethod = .categorical(.count)
            ) -> MetricSchema {
                MetricSchema(
                    name: title,
                    emoji: emoji,
                    fitPercentage: 0.80,
                    config: .categoryMultipleChoice(
                        CategoryConfig(labels: labels)
                    ),
                    visual: MetricVisual(
                        chart: chart,
                        aggregation: AggregationConfig(bucket: bucket, method: method)
                    )
                )
            }

            static func binary(
                title: String = "Workout Done",
                emoji: String = "💪",
                trueLabel: String = "Yes",
                falseLabel: String = "No",
                chart: ChartType = .calendar,
                bucket: TemporalBucket? = .daily,
                method: AggregationMethod = .categorical(.count)
            ) -> MetricSchema {
                MetricSchema(
                    name: title,
                    emoji: emoji,
                    fitPercentage: 0.92,
                    config: .binary(
                        BinaryConfig(
                            trueLabel: trueLabel,
                            falseLabel: falseLabel
                        )
                    ),
                    visual: MetricVisual(
                        chart: chart,
                        aggregation: AggregationConfig(bucket: bucket, method: method)
                    )
                )
            }

            static func datetime(
                title: String = "Wake Up Time",
                emoji: String = "⏰",
                chart: ChartType = .line,
                bucket: TemporalBucket? = .daily,
                method: AggregationMethod = .numerical(.average)
            ) -> MetricSchema {
                MetricSchema(
                    name: title,
                    emoji: emoji,
                    fitPercentage: 0.85,
                    config: .datetime(
                        DatetimeConfig()
                    ),
                    visual: MetricVisual(
                        chart: chart,
                        aggregation: AggregationConfig(bucket: bucket, method: method)
                    )
                )
            }

            static func duration(
                title: String = "Meditation Session",
                emoji: String = "🧘",
                chart: ChartType = .bar,
                bucket: TemporalBucket? = .daily,
                method: AggregationMethod = .numerical(.sum),
                behavior: MetricBehavior = .cumulative
            ) -> MetricSchema {
                MetricSchema(
                    name: title,
                    emoji: emoji,
                    fitPercentage: 0.78,
                    config: .duration(
                        DurationConfig(behavior: behavior)
                    ),
                    visual: MetricVisual(
                        chart: chart,
                        aggregation: AggregationConfig(bucket: bucket, method: method)
                    )
                )
            }
        }
    }

