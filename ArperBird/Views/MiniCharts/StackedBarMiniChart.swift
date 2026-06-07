//
//  StackedBarMiniChart.swift
//  ArperBird
//
//  Created by Olivier Picard on 28/04/2026.
//

import Charts
import SwiftUI

struct StackedBarMiniChart: MiniChart {
    struct Entry: Identifiable {
        let id = UUID()
        let timeIndex: Int
        let category: String
        let value: Double
    }

    let entries: [Entry]

    private let maxBarWidth: Double = 35
    private let barSpacing: Double = 2

    private var timeSlotCount: Int {
        Set(entries.map(\.timeIndex)).count
    }

    var body: some View {
        GeometryReader { geo in
            let count = max(timeSlotCount, 1)
            let totalSpacing = barSpacing * Double(count - 1)
            let availableWidth = max(geo.size.width - totalSpacing, 0)
            let barWidth = min(maxBarWidth, availableWidth / Double(count))
            let chartWidth = barWidth * Double(count) + totalSpacing

            Chart(entries) { entry in
                BarMark(
                    x: .value("", entry.timeIndex),
                    y: .value("y", entry.value),
                    width: .fixed(barWidth)
                )
                .foregroundStyle(by: .value("Category", entry.category))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            .frame(width: chartWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let totalDays = 14
    let labels = ["Deep", "Light", "REM", "Awake"]
    let entries: [StackedBarMiniChart.Entry] = (0..<totalDays).flatMap { day in
        labels.map { category in
            StackedBarMiniChart.Entry(
                timeIndex: day,
                category: category,
                value: Double.random(in: 5...30)
            )
        }
    }

    StackedBarMiniChart(entries: entries)
        .frame(height: 140)
        .padding()
}
