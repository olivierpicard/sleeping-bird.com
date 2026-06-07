//
//  TrailingCalendarMiniChart.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import SwiftUI

struct TrailingCalendarMiniChart: MiniChart {
    let data: [Date]
    let color: Color
    var visibleDays: Int = 7

    private let maxDotSize: Double = 36
    private let dotSpacing: Double = 6
    private let labelSpacing: Double = 6

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool {colorScheme == .dark}

    private var calendar: Calendar { .current }

    private var days: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (0..<visibleDays).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private func hasEntry(on day: Date) -> Bool {
        let target = calendar.startOfDay(for: day)
        return data.contains { calendar.startOfDay(for: $0) == target }
    }

    private func weekdayLabel(for date: Date) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        return calendar.veryShortWeekdaySymbols[index]
    }

    var body: some View {
        GeometryReader { geo in
            let slots = visibleDays
            let totalSpacing = dotSpacing * Double(slots - 1)
            let availableWidth = max(geo.size.width - totalSpacing, 0)
            let dotSize = min(maxDotSize, availableWidth / Double(slots))
            let today = calendar.startOfDay(for: .now)

            HStack(spacing: dotSpacing) {
                ForEach(days, id: \.self) { day in
                    let active = hasEntry(on: day)
                    let dayNumber = calendar.component(.day, from: day)

                    VStack(spacing: labelSpacing) {
                        Text(weekdayLabel(for: day))
                            .font(
                                .system(size: dotSize * 0.28, weight: .semibold)
                            )
                            .foregroundStyle(
                                color.mix(with: .primary, by: 0.15).opacity(
                                    0.9
                                )
                            )

                        Circle()
                            .fill(
                                active
                                    ? color.opacity(
                                        isDark ? 0.4 : 0.2
                                    ) : Color.clear
                            )
                            .overlay(
                                Circle().strokeBorder(
                                    color.opacity(isDark ? 0.8 : 0.5),
                                    lineWidth: 1
                                )
                            )
                            .overlay(
                                Text("\(dayNumber)")
                                    .font(
                                        .system(
                                            size: dotSize * 0.32,
                                            weight: .bold
                                        )
                                    )
                                    .foregroundStyle(
                                        color.mix(with: .primary, by: 0.25)
                                    )
                            )
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    let today = Date.now
    let cal = Calendar.current
    let data: [Date] = [
        cal.date(byAdding: .day, value: -1, to: today)!,
        cal.date(byAdding: .day, value: -3, to: today)!,
        today,
    ]

    TrailingCalendarMiniChart(data: data, color: .pink)
        .frame(height: 80)
        .padding()
}
