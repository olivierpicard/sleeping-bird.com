//
//  EventCalendarMiniChart.swift
//  ArperBird
//
//  Created by Olivier Picard on 11/05/2026.
//

import SwiftUI

struct EventCalendarMiniChart: MiniChart {
    let data: [Date]
    let color: Color
    var cellCount: Int = 6
    /// Opt-in reveal: when set, every cell scales in one by one, leading→trailing
    /// — filled date cells and the dashed empty slots alike ride the same wave.
    /// Off by default so the dashboard is untouched.
    var animate: Bool = false

    private let cellHeight: Double = 56
    private let cellSpacing: Double = 6
    private let cornerRadius: Double = 10

    /// The wave driver, 0→1. `didStart` makes the reveal one-shot per instance.
    @State private var progress: CGFloat = 0
    @State private var didStart = false

    private var calendar: Calendar { .current }

    private var slots: [Date?] {
        let sorted = data.sorted()
        let filled = Array(sorted.suffix(cellCount))
        let emptyCount = cellCount - filled.count
        return Array(repeating: nil, count: emptyCount)
            + filled.map(Optional.init)
    }

    private func monthLabel(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated)).uppercased()
    }

    private func dayLabel(for date: Date) -> String {
        "\(calendar.component(.day, from: date))"
    }

    var body: some View {
        HStack(spacing: cellSpacing) {
            ForEach(slots.indices, id: \.self) { index in
                // Every cell rides one wave, leading→trailing — filled dates and
                // empty slots alike scale in on their beat.
                let reveal = didStart
                    ? ChartReveal.local(progress, index: index, count: slots.count)
                    : 1
                Group {
                    if let date = slots[index] {
                        FilledCell(
                            color: color,
                            cornerRadius: cornerRadius,
                            monthLabel: monthLabel(for: date),
                            dayLabel: dayLabel(for: date)
                        )
                    } else {
                        EmptyCell(color: color, cornerRadius: cornerRadius)
                    }
                }
                // A zoom-in as the wave reaches each cell: it arrives close to the
                // screen (larger + out of focus) and recedes into its resting size,
                // sharpening as it lands — depth, not a 2D grow.
                .opacity(reveal)
                .scaleEffect(1.22 - 0.22 * reveal)
                .blur(radius: 5 * (1 - reveal))
            }
        }
        .frame(height: cellHeight)
        .onAppear {
            guard animate, !didStart else { return }
            didStart = true
            withAnimation(ChartReveal.calendarAnimation) { progress = 1 }
        }
    }
}

private struct FilledCell: View {
    let color: Color
    let cornerRadius: Double
    let monthLabel: String
    let dayLabel: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color.opacity(colorScheme == .dark ? 0.2 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(color.opacity(0.6), lineWidth: 1)
            )
            .overlay(
                VStack(spacing: 1) {
                    Text(monthLabel)
                        .font(.caption2)
//                        .fontWeight(.medium)
                        .foregroundStyle(color.mix(with: .primary, by: 0.2))
                    Text(dayLabel)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(color.mix(with: .primary, by: 0.1))
                }
            )
    }
}

private struct EmptyCell: View {
    let color: Color
    let cornerRadius: Double

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(color.opacity(0.8))
    }
}

#Preview {
    let cal = Calendar.current
    let now = Date.now
    let data: [Date] = [
        cal.date(byAdding: .day, value: -20, to: now)!,
        cal.date(byAdding: .day, value: -12, to: now)!,
        cal.date(byAdding: .day, value: -5, to: now)!,
        cal.date(byAdding: .day, value: -1, to: now)!,
    ]

    EventCalendarMiniChart(data: data, color: .indigo)
        .padding()
}
