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

    var usesCardInset: Bool { false }

    /// Max horizontal distance between two points. Points squeeze below this
    /// when data is dense, but never spread wider — keeping sparse data from
    /// looking stretched.
    private let maxPointSpacing: CGFloat = 44

    /// Min horizontal distance between two points. Once data is dense enough to
    /// fall below this, we drop the oldest points (left side) and keep only the
    /// latest that fit, rather than squeezing everything together.
    private let minPointSpacing: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let maxPoints = max(Int(geometry.size.width / minPointSpacing) + 1, 2)
            let visible = Array(data.suffix(maxPoints))
            let maxWidth = maxPointSpacing * CGFloat(max(visible.count - 1, 1))
            // A single point can't form a LineMark, so route it to a dedicated
            // single-point treatment that spans the full width.
            let chartWidth = visible.count == 1
                ? geometry.size.width
                : min(geometry.size.width, maxWidth)
            Group {
                if visible.count == 1 {
                    FlatLineSinglePoint(value: visible[0], color: color)
                } else {
                    chart(for: visible)
                }
            }
            .frame(width: chartWidth)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func chart(for data: [Double]) -> some View {
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

// MARK: - Single-point treatments (When data count == 1)

/// Vertical headroom for a single value so the flat line sits in the upper
/// portion of the plot and the area gradient stays visible beneath it.
private func singlePointDomain(for value: Double) -> ClosedRange<Double> {
    0...(value > 0 ? value * 1.5 : 1)
}

/// Flat line + area + end dot.
/// Duplicates the value so the line/area span the width (reads like a real
/// chart), then caps the actual reading with a dot at the trailing edge.
private struct FlatLineSinglePoint: View {
    let value: Double
    let color: Color

    var body: some View {
        Chart {
            ForEach([0, 1], id: \.self) { index in
                LineMark(x: .value("", index), y: .value("y", value))
                    .foregroundStyle(color.opacity(0.55))

                AreaMark(x: .value("", index), y: .value("y", value))
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
            }

            PointMark(x: .value("", 1), y: .value("y", value))
                .foregroundStyle(color)
                .symbolSize(60)
        }
        .chartYScale(domain: singlePointDomain(for: value))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

#Preview("Single point") {
    FlatLineSinglePoint(value: 50, color: .brown)
        .frame(height: 100)
        .padding()
}

#Preview("14 days worth data") {
    let totalDays = 14
    let data: [Double] = (0..<totalDays).map { i in
        if i >= totalDays - 2 { return 50 }
        return Double.random(in: 10...50)
    }
    
    LineMiniChart(data: data, color: .brown)
        .frame(height: 100)
        .padding()
}

#Preview("5 days worth data") {
    let totalDays = 5
    let data: [Double] = (0..<totalDays).map { i in
        if i >= totalDays - 2 { return 50 }
        return Double.random(in: 10...50)
    }
    
    LineMiniChart(data: data, color: .brown)
        .frame(height: 100)
        .padding()
}

// The behaviour truncate some old values
#Preview("100 days worth data") {
    let totalDays = 100
    let data: [Double] = (0..<totalDays).map { i in
        if i >= totalDays - 2 { return 50 }
        return Double.random(in: 10...50)
    }
    
    LineMiniChart(data: data, color: .brown)
        .frame(height: 100)
        .padding()
}
