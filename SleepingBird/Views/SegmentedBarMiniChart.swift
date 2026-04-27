//
//  SegmentedBarMiniChart.swift
//  SleepingBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import SwiftUI

struct SegmentedBarMiniChart: View {
    let data: [Double]
    let labels: [String]

    private static let categoryPalette: [Color] = [
        .blue, .green, .orange, .red, .purple, .teal, .pink, .yellow,
    ]

    private var total: Double { data.reduce(0, +) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let spacing: CGFloat = 1.5
                let count = CGFloat(max(data.count - 1, 0))
                let available = geo.size.width - count * spacing

                HStack(spacing: spacing) {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        let fraction = total > 0 ? value / total : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Self.categoryPalette[index % Self.categoryPalette.count])
                            .frame(width: available * fraction)
                    }
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            if !labels.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80), spacing: 8)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(Array(labels.prefix(data.count).enumerated()), id: \.offset) { index, label in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Self.categoryPalette[index % Self.categoryPalette.count])
                                .frame(width: 8, height: 8)
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SegmentedBarMiniChart(
        data: [90, 150, 45, 165, 90, 150, 45, 165, 90, 150, 45, 165],
        labels: ["Deep with a touch of fake", "Light", "REM", "Awake", "Deep2", "Light2", "REM2", "Awake2", "Deep3", "Light3", "REM3", "Awake3"]
    )
    .padding()
}
