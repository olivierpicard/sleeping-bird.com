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
    /// Opt-in reveal: when set, the whole line fades in and settles up from near
    /// its final shape (all points rise together, no wave). Off by default so the
    /// dashboard is untouched.
    var animate: Bool = false

    /// The fill driver, 0→1. `didStart` makes the reveal one-shot per instance so
    /// the Done view flipping the flag off afterwards never reverts it.
    @State private var progress: CGFloat = 0
    @State private var didStart = false

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
                    FlatLineSinglePoint(value: visible[0], color: color, animate: animate)
                } else {
                    chart(for: visible)
                }
            }
            .frame(width: chartWidth)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onAppear {
            guard animate, !didStart else { return }
            didStart = true
            // A single gentle fill: the whole line eases up and fades in together.
            withAnimation(ChartReveal.fillAnimation) { progress = 1 }
        }
    }

    private func chart(for data: [Double]) -> some View {
        // The whole line rises together (no wave): every point starts near its
        // final value (`riseFloor`) and settles the last sliver up, while the
        // chart fades in — mirroring the bar chart's fade-and-settle. A resting
        // chart (`animate == false`) draws at full directly.
        let p = animate ? progress : 1
        let rise = ChartReveal.riseFloor + (1 - ChartReveal.riseFloor) * p
        // Pin the y-domain to the final shape so the `rise` scaling is actually
        // visible — an auto-domain would rescale with the values and hold the line
        // visually static. Matches the resting auto-domain (AreaMark anchors at 0,
        // tallest point reaches the top), so a later swap to a static chart is seamless.
        let maxValue = max(data.max() ?? 1, 0.0001)
        return Chart(data.enumerated(), id: \.offset) { index, value in
            let shown = value * rise
            LineMark(
                x: .value("", index),
                y: .value("y", shown)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(color.opacity(0.55))

            AreaMark(
                x: .value("", index),
                y: .value("y", shown)
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
        .chartYScale(domain: 0...maxValue)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .opacity(animate ? Double(progress) : 1)
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
    /// Opt-in reveal: rises from the floor and fades in on entry.
    var animate: Bool = false

    @State private var fill: CGFloat = 0
    @State private var didStart = false

    /// The single reading settles up from near its value (`riseFloor`) and fades
    /// in, rather than rising the full way from zero; a resting render sits at full.
    private var shown: Double {
        guard didStart else { return value }
        let rise = ChartReveal.riseFloor + (1 - ChartReveal.riseFloor) * fill
        return value * Double(rise)
    }

    var body: some View {
        Chart {
            ForEach([0, 1], id: \.self) { index in
                LineMark(x: .value("", index), y: .value("y", shown))
                    .foregroundStyle(color.opacity(0.55))

                AreaMark(x: .value("", index), y: .value("y", shown))
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

            PointMark(x: .value("", 1), y: .value("y", shown))
                .foregroundStyle(color)
                .symbolSize(60)
        }
        // Pin to the final value's domain so the point rises within a stable
        // frame rather than the auto-domain collapsing at fill 0.
        .chartYScale(domain: singlePointDomain(for: value))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .opacity(didStart ? Double(fill) : 1)
        .onAppear {
            guard animate, !didStart else { return }
            didStart = true
            withAnimation(ChartReveal.fillAnimation) { fill = 1 }
        }
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
