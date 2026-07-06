//
//  LinearGaugeMiniChart.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/04/2026.
//

import SwiftUI

struct LinearGaugeMiniChart: MiniChart {
    let current: Double
    let goal: Double
    let color: Color
    /// Opt-in reveal: when set, the fill sweeps up from empty to its value on
    /// entry. Off by default so the dashboard is untouched.
    var animate: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    /// The reveal fill fraction, 0→1, multiplied into both bar widths. `didStart`
    /// makes the animation one-shot per instance.
    @State private var fill: CGFloat = 0
    @State private var didStart = false

    private var progress: Double { abs(current) / max(abs(goal), 0.00001) }
    private var isOverGoal: Bool { abs(current) > abs(goal) }
    private var trackOpacity: Double { colorScheme == .dark ? 0.35 : 0.2 }
    private var overflowMixColor: Color { colorScheme == .dark ? .white : .black }
    /// Sweep factor for the fills — animates in for a revealing instance, sits at
    /// full for a resting one.
    private var shownFill: CGFloat { didStart ? fill : 1 }

    var body: some View {
        VStack(alignment: .trailing) {
            GeometryReader { geo in
                let maxWidth = geo.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(trackOpacity))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: maxWidth * min(progress, 1) * shownFill)
                    if isOverGoal {
                        Capsule()
                            .fill(color.mix(with: overflowMixColor, by: 0.4))
                            .frame(
                                width: geo.size.width * min(progress - 1, 1) * shownFill
                            )
                    }
                }
            }
            .frame(height: 14)
            .onAppear {
                guard animate, !didStart else { return }
                didStart = true
                withAnimation(ChartReveal.fillAnimation) { fill = 1 }
            }

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
