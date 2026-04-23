//
//  Dashboard.swift
//  SleepingBird
//
//  Created by Olivier Picard on 22/04/2026.
//

import SwiftUI

struct Dashboard: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {

                MetricView(
                    title: "Steps",
                    emoji: "👟",
                    value: "8,432",
                    mainColor: .green,
                    data: [
                        3000, 5000, 4000, 6500, 5500, 7000, 4500, 8000, 6000,
                        9000, 7500, 8432,
                    ]
                )

                MetricView(
                    title: "Sleep",
                    emoji: "🌙",
                    value: "7h 20m",
                    mainColor: .indigo,
                    data: [
                        6.5, 7.0, 6.0, 8.0, 7.5, 6.8, 7.3, 7.0, 6.5, 7.8, 7.2,
                        7.3,
                    ]
                )

                MetricView(
                    title: "Heart Rate",
                    emoji: "❤️",
                    value: "72 bpm",
                    mainColor: .red,
                    data: [68, 72, 75, 70, 69, 74, 71, 73, 70, 72, 74, 72]
                )

                MetricView(
                    title: "Water",
                    emoji: "💧",
                    value: "1.8 L",
                    mainColor: .blue,
                    data: [
                        1.2, 1.5, 1.0, 1.8, 2.0, 1.6, 1.4, 1.9, 1.7, 1.5, 1.8,
                        1.8,
                    ]
                )

                MetricView(
                    title: "Calories",
                    emoji: "🔥",
                    value: "2,150 kcal",
                    mainColor: .orange,
                    data: [
                        1800, 2100, 1950, 2200, 2050, 2300, 1900, 2150, 2000,
                        2250, 2100, 2150,
                    ]
                )

                MetricView(
                    title: "Weight",
                    emoji: "⚖️",
                    value: "72.4 kg",
                    mainColor: .teal,
                    data: [
                        74.2, 73.8, 73.5, 73.1, 72.9, 72.7, 72.5, 72.8, 72.6,
                        72.4, 72.5, 72.4,
                    ]
                )
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

}
