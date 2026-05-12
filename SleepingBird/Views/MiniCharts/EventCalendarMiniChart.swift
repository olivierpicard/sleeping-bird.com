//
//  EventCalendarMiniChart.swift
//  SleepingBird
//
//  Created by Olivier Picard on 11/05/2026.
//

import SwiftUI

struct EventCalendarMiniChart: MiniChart {
    let data: [Date]
    let color: Color
    var cellCount: Int = 7

    private let cellHeight: Double = 56
    private let cellSpacing: Double = 6
    private let cornerRadius: Double = 10

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
//        EmptyCell(color: color, cornerRadius: cornerRadius)
        HStack(spacing: cellSpacing) {
            ForEach(slots.indices, id: \.self) { index in
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
        }
        .frame(height: cellHeight)
    }
}

private struct FilledCell: View {
    let color: Color
    let cornerRadius: Double
    let monthLabel: String
    let dayLabel: String

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(color.opacity(0.6), lineWidth: 1)
            )
            .overlay(
                VStack(spacing: 1) {
                    Text(monthLabel)
                        .font(.caption2)
                        .foregroundStyle(color)
                    Text(dayLabel)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
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
            .foregroundStyle(color.opacity(0.5))
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
