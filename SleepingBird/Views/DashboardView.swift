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
                MetricPlaceholderView()
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
//        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
    }
}

// MARK: -Preview

#Preview {
    NavigationStack {
        DashboardView()
            .environment(
                MetricStore(with: [
                    Metric(
                        from: MetricSchema.Mock.number(
                            title: "Daily Steps",
                            emoji: "👟"
                        ),
                        data: Metric.fakeData(for: MetricSchema.Mock.number().config)
                    ),
                    Metric(
                        from: MetricSchema.Mock.duration(
                            title: "Sleep",
                            emoji: "🌙"
                        )
                        ,
                        data: Metric.fakeData(for: MetricSchema.Mock.duration().config)
                    ),
                    Metric(
                        from: MetricSchema.Mock.number(
                            title: "Sleep",
                            emoji: "🌙",
                            chart: .line
                        ),
                        data: Metric.fakeData(for: MetricSchema.Mock.number().config)
                    ),
                    Metric(
                        from: MetricSchema.Mock.number(
                            title: "Heart Rate",
                            emoji: "❤️",
                            unit: "bpm"
                        ),
                        data: Metric.fakeData(for: MetricSchema.Mock.number().config)
                    ),
                    Metric(
                        from: MetricSchema.Mock.binary(
                            title: "Workout Done",
                            emoji: "💪"
                        ),
                        data: Metric.fakeData(for: MetricSchema.Mock.binary().config)
                    ),
                    Metric(
                        from: MetricSchema.Mock.categorySingle(
                            title: "Mood",
                            emoji: "😊"
                        ),
                        data: Metric.fakeData(for: MetricSchema.Mock.categorySingle().config)
                    ),
                ], isGenerating: false
                )
            )
    }
}


#Preview("Card loading - With existing one"){
    NavigationStack {
        DashboardView()
            .environment(MetricStore(with: [
                Metric(
                    from: MetricSchema.Mock.binary(
                        title: "Workout Done",
                        emoji: "💪"
                    ),
                    data: Metric.fakeData(for: MetricSchema.Mock.binary().config)
                ),
                Metric(
                    from: MetricSchema.Mock.categorySingle(
                        title: "Mood",
                        emoji: "😊"
                    ),
                    data: Metric.fakeData(for: MetricSchema.Mock.categorySingle().config)
                ),
            ], isGenerating: true))
    }
}

#Preview("Card loading - Solo"){
    NavigationStack {
        DashboardView()
            .environment(MetricStore(isGenerating: true))
    }
}
