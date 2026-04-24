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
                ForEach(Array(metricStore.store.enumerated()), id: \.offset) { index, schema in
                    MetricViewFactory.makeView(from: schema, colorIndex: index)
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
        .environment(MetricStore(with: [
            MetricSchema.Mock.number(title: "Daily Steps", emoji: "👟"),
            MetricSchema.Mock.duration(title: "Sleep", emoji: "🌙"),
            MetricSchema.Mock.number(title: "Heart Rate", emoji: "❤️", unit: "bpm"),
            MetricSchema.Mock.binary(title: "Workout Done", emoji: "💪"),
            MetricSchema.Mock.categorySingle(title: "Mood", emoji: "😊"),
        ]))
}
