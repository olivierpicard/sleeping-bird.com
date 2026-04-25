//
//  Dashboard.swift
//  SleepingBird
//
//  Created by Olivier Picard on 22/04/2026.
//

import SwiftUI

struct Dashboard: View {
    @Environment(MetricStore.self) private var metricStore

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                ForEach(Array(metricStore.store.enumerated()), id: \.offset) {
                    index,
                    schema in
                    FactoryMetricView.build(from: schema)
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Overview")
    }
}

#Preview {
    Dashboard()
        .environment(
            MetricStore(with: [
                Metric(
                    from: MetricSchema.Mock.number(
                        title: "Daily Steps",
                        emoji: "👟"
                    )
                ),
                Metric(
                    from: MetricSchema.Mock.duration(title: "Sleep", emoji: "🌙")
                ),
                Metric(
                    from: MetricSchema.Mock.number(
                        title: "Heart Rate",
                        emoji: "❤️",
                        unit: "bpm"
                    )
                ),
                Metric(
                    from: MetricSchema.Mock.binary(
                        title: "Workout Done",
                        emoji: "💪"
                    )
                ),
                Metric(
                    from: MetricSchema.Mock.categorySingle(
                        title: "Mood",
                        emoji: "😊"
                    )
                ),
            ])
        )
}
