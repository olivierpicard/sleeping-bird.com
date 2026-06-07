//
//  BarMiniChart.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import Charts
import SwiftUI

struct BarMiniChart: MiniChart {
    let data: [Double]
    let color: Color

    private let maxBarWidth: Double = 35
    private let barSpacing: Double = 2

    var body: some View {
        GeometryReader { geo in
            let count = max(data.count, 1)
            let totalSpacing = barSpacing * Double(count - 1)
            let availableWidth = max(geo.size.width - totalSpacing, 0)
            let barWidth = min(maxBarWidth, availableWidth / Double(count))
            let chartWidth = barWidth * Double(count) + totalSpacing

            Chart(data.enumerated(), id: \.offset) { index, value in
                BarMark(
                    x: .value("", index),
                    y: .value("y", value),
                    width: .fixed(barWidth)
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: color.opacity(0.55), location: 0),
                            .init(color: color.opacity(0.2), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(width: chartWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let totalDays = 30
    let data: [Double] = (0..<totalDays).map { _ in
        return Double.random(in: 10...50)
    }

    BarMiniChart(data: data, color: .brown)
        .frame(height: 100)
        .padding()
}
