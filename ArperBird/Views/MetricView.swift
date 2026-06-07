//
//  TrackerView.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/04/2026.
//

import SwiftUI

struct MetricView: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let emoji: String
    let value: String
    let mainColor: Color
    let onAddTapped: () -> Void
    let onCardTapped: () -> Void
    let chart: (any MiniChart)?

    @State private var feedbackTrigger = false

    private let emojiSize: CGFloat = 52

    private static let categoryPalette: [Color] = [
        .blue, .green, .orange, .red, .purple, .teal, .pink, .yellow,
    ]

    init(
        title: String,
        emoji: String,
        value: String,
        mainColor: Color,
        onAddTapped: @escaping () -> Void,
        onCardTapped: @escaping () -> Void = {},
        chart: (any MiniChart)? = nil
    ) {
        self.title = title
        self.emoji = emoji
        self.value = value
        self.mainColor = mainColor
        self.onAddTapped = onAddTapped
        self.onCardTapped = onCardTapped
        self.chart = chart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(emoji)
                    .font(.system(size: emojiSize * 0.6))
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
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()
                Button(action: {
                    feedbackTrigger.toggle()
                    onAddTapped()
                }) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(mainColor)
                        .padding(.vertical, 3)

                }
                .buttonStyle(.bordered)
                .tint(mainColor.mix(with: .gray, by: 0.5))
//                .shadow(
//                    color: mainColor.opacity(0.8),
//                    radius: 6,
//                    x: 0,
//                    y: 0
//                )
                .sensoryFeedback(
                    .impact(flexibility: .soft),
                    trigger: feedbackTrigger
                )

            }
            .padding(.horizontal)
            .padding(.top, 23)

            if let chart {
                AnyView(chart)
                    .frame(height: 100)
                    .padding(.horizontal)
            } else {
                NoDataMiniChart()
                    .frame(height: 100)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onCardTapped)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(mainColor, style: cardStrokeStyle)
        }
        .shadow(
            color: mainColor.opacity(cardShadowOpacity),
            radius: cardShadowRadius,
            x: 0,
            y: 0
        )

    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var cardShadowOpacity: Double {
        isDarkMode ? 0.6 : 0.5
    }

    private var cardShadowRadius: CGFloat {
//        isDarkMode ? 10 : 4
        isDarkMode ? 4 : 4
    }

    private var cardStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: isDarkMode ? 0 : 0)
    }

}

#Preview("Line Chart") {
    MetricView(
        title: "Daily Steps",
        emoji: "👟",
        value: "8,432",
        mainColor: .green,
        onAddTapped: {},
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
        onAddTapped: {},
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
        onAddTapped: {},
        chart: DividerBarMiniChart(entries: [
            .init(category: "Deep", value: 90),
            .init(category: "Light", value: 150),
            .init(category: "REM", value: 45),
            .init(category: "Awake", value: 165),
        ])
    )
    .padding()
}

#Preview("Dot Map") {
    MetricView(
        title: "Did I take my medication",
        emoji: "💊",
        value: "Good",
        mainColor: .pink,
        onAddTapped: {},
        chart: TrailingCalendarMiniChart(
            data: (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) }.filter { _ in Bool.random() },
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
        onAddTapped: {},
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
        onAddTapped: {},
        chart: nil
    )
    .padding()
}
