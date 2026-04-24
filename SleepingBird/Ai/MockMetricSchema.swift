//
//  MockMetricSchema.swift
//  SleepingBird
//
//  Created by Olivier Picard on 20/04/2026.
//

#if DEBUG
    extension MetricSchema {
        enum Mock {
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
                labels: [String] = [
                    "Great", "Good", "Neutral", "Bad", "Terrible",
                ],
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
                chart: ChartType = .heatmap,
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
                title: String = "Wake-up Time",
                emoji: String = "⏰",
                chart: ChartType = .line,
                bucket: TemporalBucket? = .daily,
                method: AggregationMethod = .numerical(.average)
            ) -> MetricSchema {
                MetricSchema(
                    name: title,
                    emoji: emoji,
                    fitPercentage: 0.85,
                    config: .datetime,
                    visual: MetricVisual(
                        chart: chart,
                        aggregation: AggregationConfig(bucket: bucket, method: method)
                    )
                )
            }

            static func duration(
                title: String = "Meditation Session",
                emoji: String = "🧘",
                granularity: String = "m",
                maxInSeconds: Int = 3600,
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
                        DurationConfig(
                            granularity: granularity,
                            maxInSeconds: maxInSeconds,
                            behavior: behavior
                        )
                    ),
                    visual: MetricVisual(
                        chart: chart,
                        aggregation: AggregationConfig(bucket: bucket, method: method)
                    )
                )
            }
        }
    }

#endif
