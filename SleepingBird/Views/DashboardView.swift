//
//  DashboardView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 22/04/2026.
//

import SwiftUI

struct DashboardView: View {
    @Environment(MetricStore.self) private var metricStore
    @State private var editingMetric: Metric? = nil

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                if metricStore.isGenerating {
                    MetricPlaceholderView()
                }
                ForEach(
                    Array(metricStore.metrics.reversed().enumerated()),
                    id: \.offset
                ) {
                    index,
                    metric in
                    MetricViewFactory.make(
                        from: metric,
                        onAddTapped: {
                            editingMetric = metric
                        }
                    )
                }
            }
            .padding()
        }
        .sheet(item: $editingMetric) { metric in
            //            AddEntrySheetFactory.make(from: metric)
            //            MetricEditor.Number(min: 1, max: 10, defaultValue: 1, step: 1)
            //                .style(.stepper)

            //            MetricEditor.Category(labels: [
            //                "Happy", "Neutral", "Sad", "Angry", "Excited", "Happy2",
            //                "Neutral2", "Sad2", "Angry2", "Excited2",
            //            ], )
            //            MetricEditor.Category(labels: [
            //                "Happy", "Neutral", "Sad", "Angry", "Excited",
            //            ], )
            //            .style(.multiple)
//            MetricEditor.Binary(
//                trueLabel: "Worked out at the gym",
//                falseLabel: "Skipped today the gym day",
//                mainColor: .green,
//                onAdd: { _ in }
//            )
            MetricEditor.Duration(granularity: "m", maxInSeconds: 90*60, defaultValue: 30*60)

        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Dashboard")
    }
}

// MARK: -Preview

#Preview {
    NavigationStack {
        DashboardView()
            .environment(
                MetricStore(
                    with: [
                        Metric(
                            from: MetricSchema.Fake.number(
                                title: "Daily Steps",
                                emoji: "👟"
                            ),
                            data: Metric.fakeData(
                                for: MetricSchema.Fake.number().config
                            )
                        ),
                        Metric(
                            from: MetricSchema.Fake.duration(
                                title: "Sleep",
                                emoji: "🌙"
                            ),
                            data: Metric.fakeData(
                                for: MetricSchema.Fake.duration().config
                            )
                        ),
                        Metric(
                            from: MetricSchema.Fake.number(
                                title: "Sleep",
                                emoji: "🌙",
                                chart: .line
                            ),
                            data: Metric.fakeData(
                                for: MetricSchema.Fake.number().config
                            )
                        ),
                        Metric(
                            from: MetricSchema.Fake.number(
                                title: "Heart Rate",
                                emoji: "❤️",
                                unit: "bpm"
                            ),
                            data: Metric.fakeData(
                                for: MetricSchema.Fake.number().config
                            )
                        ),
                        Metric(
                            from: MetricSchema.Fake.binary(
                                title: "Workout Done",
                                emoji: "💪"
                            ),
                            data: Metric.fakeData(
                                for: MetricSchema.Fake.binary().config
                            )
                        ),
                        Metric(
                            from: MetricSchema.Fake.categorySingle(
                                title: "Mood",
                                emoji: "😊"
                            ),
                            data: Metric.fakeData(
                                for: MetricSchema.Fake.categorySingle().config
                            )
                        ),
                    ],
                    isGenerating: false
                )
            )
    }
}

#Preview("Card loading - With existing one") {
    NavigationStack {
        DashboardView()
            .environment(
                MetricStore(
                    with: [
                        Metric(
                            from: MetricSchema.Fake.binary(
                                title: "Workout Done",
                                emoji: "💪"
                            ),
                            data: Metric.fakeData(
                                for: MetricSchema.Fake.binary().config
                            )
                        ),
                        Metric(
                            from: MetricSchema.Fake.categorySingle(
                                title: "Mood",
                                emoji: "😊"
                            ),
                            data: Metric.fakeData(
                                for: MetricSchema.Fake.categorySingle().config
                            )
                        ),
                    ],
                    isGenerating: true
                )
            )
    }
}

#Preview("Card loading - Solo") {
    NavigationStack {
        DashboardView()
            .environment(MetricStore(isGenerating: true))
    }
}
