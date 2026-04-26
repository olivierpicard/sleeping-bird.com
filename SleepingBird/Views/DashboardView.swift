//
//  DashboardView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 22/04/2026.
//

import SwiftUI

struct DashboardView: View {
    @Environment(MetricStore.self) private var metricStore

    var body: some View {
        ScrollView(.vertical) {
        VStack(spacing: 16) {
            if(metricStore.isGenerating) {
                
            }
            ForEach(Array(metricStore.store.reversed().enumerated()), id: \.offset) {
                    index,
                    metric in
                    MetricViewFactory.build(from: metric)
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
    NavigationStack {
        DashboardView()
            .environment(
                MetricStore(with: [
                    Metric(
                        from: MetricSchema.Mock.number(
                            title: "Daily Steps",
                            emoji: "👟"
                        )
                    ),
                    Metric(
                        from: MetricSchema.Mock.duration(
                            title: "Sleep",
                            emoji: "🌙"
                        )
                    ),
                    Metric(
                        from: MetricSchema.Mock.number(
                            title: "Sleep",
                            emoji: "🌙",
                            chart: .line
                        )
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
                ], isGenerating: false
                )
            )
    }
}


#Preview("Card loading"){
    DashboardView()
        .environment(MetricStore(with: [
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
        ], isGenerating: true))
}
