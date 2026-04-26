//
//  TrackerView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 21/04/2026.
//

import Charts
import SwiftUI

struct MetricView: View {
    let title: String
    let emoji: String
    let value: String
    let mainColor: Color
    let chartType: ChartType
    let labels: [String]
    let goal: Double?
    var data: [Double] = []
    @State private var emojiSize: CGFloat = 52

    private static let categoryPalette: [Color] = [
        .blue, .green, .orange, .red, .purple, .teal, .pink, .yellow,
    ]

    init(
        title: String,
        emoji: String,
        value: String,
        mainColor: Color,
        data: [Double] = [],
        hideAddButton: Bool = false,
        chartType: ChartType = .line,
        labels: [String] = [],
        goal: Double? = nil
    ) {
        self.title = title
        self.emoji = emoji
        self.value = value
        self.mainColor = mainColor
        self.data = data
        self.chartType = chartType
        self.labels = labels
        self.goal = goal
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

            if !data.isEmpty {
                chartContent
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

    // MARK: - Chart Router

    @ViewBuilder
    private var chartContent: some View {
        switch chartType {
        case .line:
            lineChart
        case .bar:
            barChart
        case .pie:
            linearCategoryChart
        //        case .dotmap:
        //            dotmapChart
        case .heatmap:
            dotmapChart
        case .gauge:
            linearGaugeChart
        }
    }

    // MARK: - Line Chart

    private var lineChart: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) {
                index,
                value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(mainColor)
                .interpolationMethod(.catmullRom)
                AreaMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: mainColor.opacity(0.35), location: 0),
                            .init(color: mainColor.opacity(0), location: 0.8),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (data.min() ?? 0)...(data.max() ?? 1))
        .frame(height: 100)
    }

    // MARK: - Bar Chart

    private var barChart: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                BarMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(mainColor.gradient)
                .cornerRadius(3)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 100)
    }

    // MARK: - Linear Category (Pie)

    private var linearCategoryChart: some View {
        let total = data.reduce(0, +)

        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let spacing: CGFloat = 1.5
                let count = CGFloat(max(data.count - 1, 0))
                let available = geo.size.width - count * spacing

                HStack(spacing: spacing) {
                    ForEach(Array(data.enumerated()), id: \.offset) {
                        index,
                        value in
                        let fraction = total > 0 ? value / total : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                Self.categoryPalette[
                                    index % Self.categoryPalette.count
                                ]
                            )
                            .frame(width: available * fraction)
                    }
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            if !labels.isEmpty {
                HStack(spacing: 12) {
                    ForEach(
                        Array(labels.prefix(data.count).enumerated()),
                        id: \.offset
                    ) { index, label in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(
                                    Self.categoryPalette[
                                        index % Self.categoryPalette.count
                                    ]
                                )
                                .frame(width: 8, height: 8)
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Dot Map

    private var dotmapChart: some View {
        let totalSlots = 14
        let slice = Array(data.suffix(totalSlots))
        let padded =
            Array(repeating: 0.0, count: max(0, totalSlots - slice.count))
            + slice
        let maxVal = slice.max() ?? 1
        let dotSize: CGFloat = 16
        let spacing: CGFloat = 6

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: spacing) {
                ForEach(0..<totalSlots, id: \.self) { i in
                    let intensity = maxVal > 0 ? padded[i] / maxVal : 0
                    Circle()
                        .fill(mainColor.opacity(intensity))
                        .overlay(
                            Circle().strokeBorder(
                                mainColor.opacity(0.8),
                                lineWidth: 1
                            )
                        )
                        .frame(width: dotSize, height: dotSize)
                }
            }
            .frame(maxWidth: .infinity)

        }
        .padding()
    }

    // MARK: - Heatmap (GitHub-style)

    private var heatmapChart: some View {
        let maxVal = data.max() ?? 1
        let rows = 7

        return LazyHGrid(
            rows: Array(
                repeating: GridItem(.fixed(12), spacing: 2),
                count: rows
            ),
            spacing: 2
        ) {
            ForEach(0..<data.count, id: \.self) { i in
                let intensity = maxVal > 0 ? data[i] / maxVal : 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(mainColor.opacity(max(0.08, intensity * 0.9)))
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Linear Gauge

    private var linearGaugeChart: some View {
        let current = data.last ?? 0
        let maxValue = goal ?? data.max() ?? 1
        let progress = min(max(current / maxValue, 0), 1)

        return VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(mainColor.opacity(0.12))
                    Capsule()
                        .fill(mainColor.gradient)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 14)

            if let goal {
                Text("Goal: \(goal, format: .number)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview("Line Chart") {
    MetricView(
        title: "Daily Steps",
        emoji: "👟",
        value: "8,432",
        mainColor: .green,
        data: [
            3000, 5000, 4000, 6500, 5500, 7000, 4500, 8000, 6000, 9000, 7500,
            8432,
        ],
        chartType: .line
    )
    .padding()
}
#Preview("Bar Chart") {
    MetricView(
        title: "Calories",
        emoji: "🔥",
        value: "1,840 kcal",
        mainColor: .orange,
        data: [
            1200, 1500, 1800, 1400, 2000, 1700, 1840, 1200, 1500, 1800, 1400,
            2000, 1700, 1840,
        ],
        chartType: .bar
    )
    .padding()
}

#Preview("Category (Pie)") {
    MetricView(
        title: "Sleep Stages",
        emoji: "🌙",
        value: "7h 30m",
        mainColor: .indigo,
        data: [90, 150, 45, 165],
        chartType: .pie,
        labels: ["Deep", "Light", "REM", "Awake"]
    )
    .padding()
}

#Preview("Dot Map") {
    MetricView(
        title: "Did I take my medication",
        emoji: "💊",
        value: "Good",
        mainColor: .pink,
        data: [
            0, 1, 0.8, 0.3, 1, 0.6, 0, 0, 1, 0.8, 0.3, 1, 0.6, 0,
        ],
        chartType: .heatmap
    )
    .padding()
}

//#Preview("Heatmap") {
//    MetricView(
//        title: "Workout Days",
//        emoji: "💪",
//        value: "18 / 30",
//        mainColor: .purple,
//        data: Array((0..<158).map { _ in Double.random(in: 0...5) }),
//        chartType: .heatmap
//    )
//    .padding()
//}

#Preview("Gauge") {
    MetricView(
        title: "Water Intake",
        emoji: "💧",
        value: "1.8 L",
        mainColor: .blue,
        data: [1.8],
        chartType: .gauge,
        goal: 2.5
    )
    .padding()
}
