//
//  MetricView.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/04/2026.
//

import SwiftUI
import TipKit

/// A metric card. The header and chart are injected, so the same card chrome
/// (background, border, shadow, tap handling) is reused for read-only cards and
/// for the editable "create a tracker" flow.
struct MetricView<Header: View, Chart: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let mainColor: Color
    let onCardTapped: () -> Void
    @ViewBuilder let header: () -> Header
    @ViewBuilder let chart: () -> Chart

    init(
        mainColor: Color,
        onCardTapped: @escaping () -> Void = {},
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder chart: @escaping () -> Chart
    ) {
        self.mainColor = mainColor
        self.onCardTapped = onCardTapped
        self.header = header
        self.chart = chart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header()
                .padding(.horizontal)
                .padding(.top, 23)

            chart()
                .frame(height: 100)
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
        .task {
            guard !AddEntryTip.hasSettled else { return }
            try? await Task.sleep(for: .seconds(3.5))
            AddEntryTip.hasSettled = true
        }
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var cardShadowOpacity: Double {
        isDarkMode ? 0.6 : 0.5
    }

    private var cardShadowRadius: CGFloat {
        isDarkMode ? 4 : 4
    }

    private var cardStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: isDarkMode ? 0 : 0)
    }
}

// MARK: - Convenience: standard read-only card

extension MetricView where Header == MetricHeaderValueView, Chart == AnyView {
    /// The standard card: a text header and an optional `MiniChart`
    /// (falling back to `NoDataMiniChart`). Keeps every existing call site unchanged.
    init(
        title: String,
        emoji: String,
        value: String,
        mainColor: Color,
        onAddTapped: @escaping () -> Void = {},
        onCardTapped: @escaping () -> Void = {},
        chart: (any MiniChart)? = nil
    ) {
        self.init(
            mainColor: mainColor,
            onCardTapped: onCardTapped,
            header: {
                MetricHeaderValueView(
                    title: title,
                    emoji: emoji,
                    value: value,
                    mainColor: mainColor,
                    onAddTapped: onAddTapped
                )
            },
            chart: {
                AnyView(
                    Group {
                        if let chart {
                            AnyView(chart)
                                .padding(.horizontal)
                        } else {
                            NoDataMiniChart()
                        }
                    }
                )
            }
        )
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

#Preview("Editable header") {
    @Previewable @State var title = ""
    MetricView(
        mainColor: .gray,
        header: {
            MetricHeaderEditingView(
                emoji: "🫥",
                mainColor: .gray,
                title: $title,
                placeholder: "Tracker name"
            )
        },
        chart: { NoDataMiniChart() }
    )
    .padding()
}
