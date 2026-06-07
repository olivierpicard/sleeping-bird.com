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

    var body: some View {
        Chart(entries) { entry in
            BarMark(
                x: .value("Value", entry.value)
            )
            .foregroundStyle(by: .value("Category", entry.category))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
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
