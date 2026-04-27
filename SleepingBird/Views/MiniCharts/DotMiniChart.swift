//
//  DotChartCardView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import SwiftUI

struct DotMiniChart: MiniChart {
    let data: [Double]
    let color: Color

    private let maxDotSize: Double = 25
    private let dotSpacing: Double = 6

    var body: some View {
        GeometryReader { geo in
            let slotsAtMax = max(
                Int((geo.size.width + dotSpacing) / (maxDotSize + dotSpacing)),
                1
            )
            let totalSlots = max(data.count, slotsAtMax)
            let totalSpacing = dotSpacing * Double(totalSlots - 1)
            let availableWidth = max(geo.size.width - totalSpacing, 0)
            let dotSize = min(maxDotSize, availableWidth / Double(totalSlots))
            let maxVal = data.max() ?? 1
            let emptyCount = max(totalSlots - data.count, 0)
            let padded = Array(repeating: 0.0, count: emptyCount) + data

            HStack(spacing: dotSpacing) {
                ForEach(Array(padded.enumerated()), id: \.offset) { _, value in
                    let intensity = maxVal > 0 ? value / maxVal : 0
                    Circle()
                        .fill(color.opacity(intensity))
                        .overlay(
                            Circle().strokeBorder(
                                color.opacity(0.8),
                                lineWidth: 1
                            )
                        )
                        .frame(width: dotSize, height: dotSize)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .leading
            )
        }
    }
}

#Preview {
    let totalDays = 14
    let data: [Double] = (0..<totalDays).map { _ in
        return Double.random(in: 0...1)
    }

    DotMiniChart(data: data, color: .pink)
        .frame(height: 100)
        .padding()
}
