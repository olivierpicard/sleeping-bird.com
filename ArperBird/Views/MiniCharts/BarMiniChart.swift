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

    private let maxBarWidth: Double = 14
    private let minBarWidth: Double = 8
    private let barSpacing: Double = 5

    var body: some View {
        GeometryReader { geo in
            // How many bars fit while each stays at least `minBarWidth` wide.
            // Drop older values so the latest bars satisfy the min requirement.
            let maxBars = max(
                Int((geo.size.width + barSpacing) / (minBarWidth + barSpacing)),
                1
            )
            let visibleData = Array(data.suffix(maxBars))

            let count = max(visibleData.count, 1)
            let totalSpacing = barSpacing * Double(count - 1)
            let availableWidth = max(geo.size.width - totalSpacing, 0)
            let barWidth = min(
                maxBarWidth,
                max(minBarWidth, availableWidth / Double(count))
            )
            let chartWidth = barWidth * Double(count) + totalSpacing

            Chart(visibleData.enumerated(), id: \.offset) { index, value in
                BarMark(
                    x: .value("", index),
                    y: .value("y", value),
                    width: .fixed(barWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

#Preview("30 days worthdata") {
    let totalDays = 30
    let data: [Double] = (0..<totalDays).map { i in
        if i >= totalDays - 2 { return 50 }
        return Double.random(in: 10...50)
    }

    BarMiniChart(data: data, color: .brown)
        .frame(height: 100)
        .padding()
}

#Preview("5 days worthdata") {
    let totalDays = 5
    let data: [Double] = (0..<totalDays).map { i in
        if i >= totalDays - 2 { return 50 }
        return Double.random(in: 10...50)
    }

    BarMiniChart(data: data, color: .brown)
        .frame(height: 100)
        .padding()
}

#Preview("100 days worthdata") {
    let totalDays = 100
    let data: [Double] = (0..<totalDays).map { i in
        if i >= totalDays - 2 { return 50 }
        return Double.random(in: 10...50)
    }

    BarMiniChart(data: data, color: .brown)
        .frame(height: 100)
        .padding()
}
