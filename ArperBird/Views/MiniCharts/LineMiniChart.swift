//
//  LineChartView.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import Charts
import SwiftUI

struct LineMiniChart: MiniChart {
    let data: [Double]
    let color: Color
    
    var body: some View {
        Chart(data.enumerated(), id: \.offset) { index, value in
            LineMark(
                x: .value("", index),
                y: .value("y", value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(color.opacity(0.55))

            AreaMark(
                x: .value("", index),
                y: .value("y", value)
            )
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: color.opacity(0.35), location: 0),
                        .init(color: color.opacity(0), location: 0.8),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

#Preview {
    let totalDays = 14
    let calendar = Calendar.current
    let today = Date()
    let data: [Double] = (0..<totalDays).map { _ in
        return Double.random(in: 10...50)
    }
    
    LineMiniChart(data: data, color: .brown)
        .frame(height: 100)
        .padding()
}
