//
//  TrailingCalendarMiniChart.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import SwiftUI

struct TrailingCalendarMiniChart: MiniChart {
    let data: [Date]
    var falseData: [Date] = []
    let color: Color
    var visibleDays: Int = 7
    /// Opt-in reveal: when set, every day cell scales in one by one,
    /// leading→trailing — logged days and the dashed empty "waiting" slots alike
    /// ride the same wave. Off by default so the dashboard is untouched.
    var animate: Bool = false

    private enum DayState { case filled, negative, empty }

    private let maxDotSize: Double = 36
    private let dotSpacing: Double = 6
    private let labelSpacing: Double = 6

    /// The wave driver, 0→1. `didStart` makes the reveal one-shot per instance.
    @State private var progress: CGFloat = 0
    @State private var didStart = false

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool {colorScheme == .dark}

    private var calendar: Calendar { .current }

    private var days: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (0..<visibleDays).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private func dayState(on day: Date) -> DayState {
        let target = calendar.startOfDay(for: day)
        if data.contains(where: { calendar.startOfDay(for: $0) == target }) {
            return .filled
        }
        if falseData.contains(where: { calendar.startOfDay(for: $0) == target }) {
            return .negative
        }
        return .empty
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

            HStack(spacing: dotSpacing) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let state = dayState(on: day)
                    let dayNumber = calendar.component(.day, from: day)
                    // Every cell rides one wave, leading→trailing — logged days
                    // and empty "waiting" slots alike scale in on their beat.
                    let reveal = didStart
                        ? ChartReveal.local(progress, index: index, count: slots)
                        : 1

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
                                {
                                    switch state {
                                    case .filled:
                                        return color.opacity(isDark ? 0.4 : 0.2)
                                    case .negative:
                                        return Color.secondary.opacity(0.35)
                                    case .empty:
                                        return Color.clear
                                    }
                                }()
                            )
                            .overlay(
                                Circle().strokeBorder(
                                    // A logged "false" reads as a solid gray
                                    // fill; true keeps the tinted ring; empty
                                    // days stay a dashed "waiting" ring.
                                    state == .negative
                                        ? Color.secondary.opacity(0.5)
                                        : color.opacity(isDark ? 0.8 : 0.5),
                                    style: StrokeStyle(
                                        lineWidth: 1,
                                        dash: state == .empty ? [3, 3] : []
                                    )
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
                    // A zoom-in as the wave reaches each cell: it arrives close to
                    // the screen (larger + out of focus) and recedes into its
                    // resting size, sharpening as it lands — depth, not a 2D grow.
                    .opacity(reveal)
                    .scaleEffect(1.22 - 0.22 * reveal)
                    .blur(radius: 5 * (1 - reveal))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            guard animate, !didStart else { return }
            didStart = true
            withAnimation(ChartReveal.calendarAnimation) { progress = 1 }
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
    let falseData: [Date] = [
        cal.date(byAdding: .day, value: -2, to: today)!,
        cal.date(byAdding: .day, value: -5, to: today)!,
    ]

    TrailingCalendarMiniChart(data: data, falseData: falseData, color: .pink)
        .frame(height: 80)
        .padding()
}
