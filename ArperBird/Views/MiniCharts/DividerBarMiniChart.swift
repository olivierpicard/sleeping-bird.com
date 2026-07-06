//
//  SegmentedBarMiniChart.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import Charts
import SwiftUI

struct DividerBarMiniChart: MiniChart {
    struct Entry: Identifiable {
        let id = UUID()
        let category: String
        let value: Double
    }

    let entries: [Entry]
    /// Opt-in reveal: when set, the segments build in one by one, leading→trailing,
    /// each growing its width into place. Off by default so the dashboard is
    /// untouched.
    var animate: Bool = false

    /// The wave driver, 0→1. `didStart` makes the reveal one-shot per instance.
    @State private var progress: CGFloat = 0
    @State private var didStart = false

    var body: some View {
        // Pin the x-domain to the full total so segments reveal within a stable
        // width instead of the bar rescaling as each grows in.
        let total = max(entries.reduce(0) { $0 + $1.value }, 0.0001)
        return revealed(chart, total: total)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .frame(height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            .onAppear {
                guard animate, !didStart else { return }
                didStart = true
                withAnimation(ChartReveal.animation) { progress = 1 }
            }
    }

    private var chart: some View {
        Chart(Array(entries.enumerated()), id: \.element.id) { index, entry in
            // Grow each segment's width on its beat of the wave; a resting bar
            // shows the full value immediately.
            let shown = didStart
                ? entry.value * ChartReveal.local(progress, index: index, count: entries.count)
                : entry.value
            BarMark(
                x: .value("Value", shown)
            )
            .foregroundStyle(by: .value("Category", entry.category))
        }
    }

    /// Pins the x-domain only for a revealing instance so the resting chart (and
    /// the dashboard) keeps its own auto-scaled width.
    @ViewBuilder
    private func revealed(_ chart: some View, total: Double) -> some View {
        if didStart {
            chart.chartXScale(domain: 0...total)
        } else {
            chart
        }
    }
}

#Preview {
    VStack {
        DividerBarMiniChart(entries: [
            .init(category: "Deep with a touch of fake", value: 90),
            .init(category: "Deep with a touch of fake", value: 690),
            .init(category: "Light", value: 150),
            .init(category: "REM", value: 45),
            .init(category: "Awake", value: 165),
            .init(category: "Deep2", value: 90),
            .init(category: "Light2", value: 150),
            .init(category: "REM2", value: 45),
            .init(category: "Awake2", value: 165),
            .init(category: "Deep3", value: 90),
            .init(category: "Light3", value: 150),
            .init(category: "REM3", value: 45),
            .init(category: "Awake3", value: 165),
        ])
        .padding()

        Divider()

        DividerBarMiniChart(entries: [
            .init(category: "Deep", value: 90),
            .init(category: "Light", value: 150),
            .init(category: "REM", value: 45),
            .init(category: "Awake", value: 165),
        ])
        .padding()
    }
}
