//
//  TrackerView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 21/04/2026.
//

import SwiftUI

struct MetricView: View {
    let title: String
    let emoji: String
    let value: String
    let mainColor: Color
    let chart: (any MiniChart)?

    @State private var emojiSize: CGFloat = 52

    private static let categoryPalette: [Color] = [
        .blue, .green, .orange, .red, .purple, .teal, .pink, .yellow,
    ]

    init(
        title: String,
        emoji: String,
        value: String,
        mainColor: Color,
        chart: (any MiniChart)? = nil
    ) {
        self.title = title
        self.emoji = emoji
        self.value = value
        self.mainColor = mainColor
        self.chart = chart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(emoji)
                    .font(.system(size: emojiSize * 0.5))
                    .frame(width: emojiSize, height: emojiSize)
                    .background {
                        mainColor.opacity(0.03)
                            .background(.ultraThinMaterial)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(mainColor.opacity(0.4), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text(title.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 38))
                        .fontWeight(.light)
                }
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    emojiSize = $0
                }
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: emojiSize * 0.8, height: emojiSize * 0.8)
                .background(mainColor)
                .clipShape(Circle())
                .shadow(
                    color: mainColor.opacity(0.6),
                    radius: 10,
                    x: 0,
                    y: 3
                )
                .buttonStyle(.plain)

            }
            .padding(.horizontal)
            .padding(.top, 23)

            if let chart {
                AnyView(chart)
                    .frame(height: 100)
                    .padding(.horizontal)
            } else {
                NoDataMiniChart(color: mainColor)
                    .frame(height: 100)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(mainColor, style: StrokeStyle(lineWidth: 0.4))
        }
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

    }

}

#Preview("Line Chart") {
    MetricView(
        title: "Daily Steps",
        emoji: "👟",
        value: "8,432",
        mainColor: .green,
        chart: LineMiniChart(
            data: [
                3000, 5000, 4000, 6500, 5500, 7000, 4500, 8000, 6000, 9000,
                7500, 8432,
            ],
            color: .green
        )
    )
    .padding()
}

#Preview("Bar Chart") {
    MetricView(
        title: "Calories",
        emoji: "🔥",
        value: "1,840 kcal",
        mainColor: .orange,
        chart: BarMiniChart(
            data: [
                1200, 1500, 1800, 1400, 2000, 1700, 1840, 1200, 1500, 1800,
                1400, 2000, 1700, 1840,
            ],
            color: .orange
        )
    )
    .padding()
}

#Preview("Segmented Bar") {
    MetricView(
        title: "Sleep Stages",
        emoji: "🌙",
        value: "7h 30m",
        mainColor: .indigo,
        chart: SegmentedBarMiniChart(
            data: [90, 150, 45, 165],
            labels: ["Deep", "Light", "REM", "Awake"]
        )
    )
    .padding()
}

#Preview("Dot Map") {
    MetricView(
        title: "Did I take my medication",
        emoji: "💊",
        value: "Good",
        mainColor: .pink,
        chart: DotMiniChart(
            data: [0, 1, 0.8, 0.3, 1, 0.6, 0, 0, 1, 0.8, 0.3, 1, 0.6, 0],
            color: .pink
        )
    )
    .padding()
}

#Preview("Gauge") {
    MetricView(
        title: "Water Intake",
        emoji: "💧",
        value: "1.8 L",
        mainColor: .blue,
        chart: LinearGaugeMiniChart(current: 1.8, goal: 2.5, color: .blue)
    )
    .padding()
}

#Preview("No Chart") {
    MetricView(
        title: "Mood",
        emoji: "😊",
        value: "Good",
        mainColor: .purple,
        chart: nil
    )
    .padding()
}
