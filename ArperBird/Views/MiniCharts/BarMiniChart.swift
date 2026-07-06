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
    /// Opt-in reveal: when set, the bars grow from the baseline as a wave sweeping
    /// leading→trailing on entry. Off by default so the dashboard is untouched.
    var animate: Bool = false

    private let maxBarWidth: Double = 14
    private let minBarWidth: Double = 8
    private let barSpacing: Double = 5

    /// The wave driver, 0→1. Read to derive each bar's grown height. Once this
    /// instance has started its reveal (`didStart`), the treatment is permanent,
    /// so the Done view flipping the flag off after the reveal never reverts it.
    @State private var progress: CGFloat = 0
    @State private var didStart = false

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

            content(visibleData, barWidth: barWidth, count: count)
                .frame(width: chartWidth)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onAppear {
            guard animate, !didStart else { return }
            didStart = true
            withAnimation(ChartReveal.animation) { progress = 1 }
        }
    }

    /// A revealing instance drives its chart through `ChartWaveReveal`, which
    /// ticks `progress` frame by frame so each bar grows on its own beat; the
    /// resting instance (the dashboard) draws the finished chart directly, so its
    /// auto-scaled domain stays untouched.
    ///
    /// Gated on `animate` (a constant) rather than a `@State` flag on purpose:
    /// the wave depends on `progress` interpolating on a *stable* view. If the
    /// branch flipped mid-life, SwiftUI would insert a fresh `ChartWaveReveal`
    /// already at `progress == 1` and skip the animation entirely.
    @ViewBuilder
    private func content(_ visibleData: [Double], barWidth: Double, count: Int) -> some View {
        if animate {
            // Pin the y-domain so bars grow against a stable ceiling instead of
            // the auto-domain rescaling frame by frame as heights change. Match
            // the resting chart's auto-domain exactly — bars anchor at 0 and the
            // tallest reaches the top (`0...max`, no headroom) — so when this
            // revealing instance is later swapped for a static one there's no
            // rescale. The 15% headroom used before showed up as an abrupt jump
            // of every bar the moment the wave finished.
            let maxValue = max(visibleData.max() ?? 1, 0.0001)
            ChartWaveReveal(progress: progress) { p in
                chart(visibleData, barWidth: barWidth, count: count, progress: p)
                    .chartYScale(domain: 0...maxValue)
            }
        } else {
            chart(visibleData, barWidth: barWidth, count: count, progress: 1)
        }
    }

    private func chart(
        _ visibleData: [Double],
        barWidth: Double,
        count: Int,
        progress: CGFloat
    ) -> some View {
        Chart(visibleData.enumerated(), id: \.offset) { index, value in
            // On its own beat of the wave, each bar fades in while its top edge
            // settles the last sliver up into place (from `riseFloor` to full) —
            // an Apple-style fade-and-settle rather than pumping up from zero. At
            // `progress == 1` — and for the resting chart, which passes 1 —
            // `local` is 1, so opacity is 1 and `shown` is the real value.
            let local = ChartReveal.local(progress, index: index, count: count)
            let shown = value * (ChartReveal.riseFloor + (1 - ChartReveal.riseFloor) * local)
            BarMark(
                x: .value("", index),
                y: .value("y", shown),
                width: .fixed(barWidth)
            )
            .opacity(local)
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
