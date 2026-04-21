//
//  MockMetricSuggestion.swift
//  SleepingBird
//
//  Created by Olivier Picard on 20/04/2026.
//

#if DEBUG
    extension MetricSuggestion {
        enum Mock {
            static func number(
                title: String = "Daily Steps",
                unit: String? = "steps",
                min: Double = 0,
                max: Double = 50_000,
                granularity: Double = 100,
                goal: Double? = 10_000
            ) -> MetricSuggestion {
                MetricSuggestion(
                    name: title,
                    fitPercentage: 0.95,
                    config: .number(
                        NumberConfig(
                            min: min,
                            max: max,
                            granularity: granularity,
                            unit: unit,
                            goal: goal
                        )
                    )
                )
            }

            static func categorySingle(
                title: String = "Mood",
                labels: [String] = [
                    "Great", "Good", "Neutral", "Bad", "Terrible",
                ]
            ) -> MetricSuggestion {
                MetricSuggestion(
                    name: title,
                    fitPercentage: 0.88,
                    config: .categorySingleChoice(
                        CategoryConfig(labels: labels)
                    )
                )
            }

            static func categoryMultiple(
                title: String = "Symptoms",
                labels: [String] = [
                    "Headache", "Fatigue", "Nausea", "Back pain", "Anxiety",
                ]
            ) -> MetricSuggestion {
                MetricSuggestion(
                    name: title,
                    fitPercentage: 0.80,
                    config: .categoryMultipleChoice(
                        CategoryConfig(labels: labels)
                    )
                )
            }

            static func binary(
                title: String = "Workout Done",
                trueLabel: String = "Yes",
                falseLabel: String = "No"
            ) -> MetricSuggestion {
                MetricSuggestion(
                    name: title,
                    fitPercentage: 0.92,
                    config: .binary(
                        BinaryConfig(
                            trueLabel: trueLabel,
                            falseLabel: falseLabel
                        )
                    )
                )
            }

            static func datetime(title: String = "Wake-up Time")
                -> MetricSuggestion
            {
                MetricSuggestion(
                    name: title,
                    fitPercentage: 0.85,
                    config: .datetime(DatetimeConfig())
                )
            }

            static func duration(
                title: String = "Meditation Session",
                granularity: String = "m",
                maxInSeconds: Int = 3600
            ) -> MetricSuggestion {
                MetricSuggestion(
                    name: title,
                    fitPercentage: 0.78,
                    config: .duration(
                        DurationConfig(
                            granularity: granularity,
                            maxInSeconds: maxInSeconds
                        )
                    )
                )
            }
        }
    }

#endif
