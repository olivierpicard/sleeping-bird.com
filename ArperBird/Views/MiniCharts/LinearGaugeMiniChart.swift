//
//  LinearGaugeMiniChart.swift
//  SleepingBird
//
//  Created by Olivier Picard on 27/04/2026.
//

import SwiftUI

struct LinearGaugeMiniChart: MiniChart {
    let current: Double
    let goal: Double
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double { abs(current) / max(abs(goal), 0.00001) }
    private var isOverGoal: Bool { abs(current) > abs(goal) }
    private var trackOpacity: Double { colorScheme == .dark ? 0.35 : 0.2 }
    private var overflowMixColor: Color { colorScheme == .dark ? .white : .black }

    var body: some View {
        VStack(alignment: .trailing) {
            GeometryReader { geo in
                let maxWidth = geo.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(trackOpacity))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: maxWidth * min(progress, 1))
                    if isOverGoal {
                        Capsule()
                            .fill(color.mix(with: overflowMixColor, by: 0.4))
                            .frame(
                                width: (geo.size.width * min(progress - 1, 1))
                            )
                    }
                }
            }
            .frame(height: 14)

            HStack {
                Text("Current: \(current, format: .number)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()

                Text("Goal: \(goal, format: .number)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Under goal") {
    LinearGaugeMiniChart(current: 1.2, goal: 2.5, color: .blue)
        .padding()
}

#Preview("At goal") {
    LinearGaugeMiniChart(current: 2.5, goal: 2.5, color: .blue)
        .padding()
}

#Preview("Over goal") {
    LinearGaugeMiniChart(current: 12, goal: 2.5, color: .blue)
        .padding()
}

#Preview("Negative") {
    VStack {
        LinearGaugeMiniChart(current: -10, goal: -20, color: .blue)
            .padding()
        
        LinearGaugeMiniChart(current: -25, goal: -20, color: .blue)
            .padding()
        
        LinearGaugeMiniChart(current: -40, goal: -20, color: .blue)
            .padding()
    }
}
