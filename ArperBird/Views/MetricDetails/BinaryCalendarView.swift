//
//  BinaryCalendarView.swift
//  ArperBird
//
//  Created by Olivier Picard on 04/05/2026.
//

import SwiftUI

struct BinaryCalendarView: View {
    let filledDays: Set<Date>
    var falseDays: Set<Date> = []
    let startMonth: Date
    let endMonth: Date
    let tint: Color
    let trueLabel: String
    let falseLabel: String
    let cellSize: Double = 270
    let monthPadding: Double = 40
    let displayLegend: Bool = false
    @Binding var selectedDate: Date?
    /// Optional two-way binding to the month currently aligned in the scroll
    /// view. When provided, drives an external month selector.
    var scrolledMonth: Binding<Date?>? = nil
    /// Reports live scroll progress in month units (0 = first month, N-1 =
    /// last), updating continuously during a swipe so an external selector can
    /// follow the drag rather than only snapping at rest.
    var onMonthProgress: ((Double) -> Void)? = nil

    /// Horizontal distance between the leading edges of two adjacent months.
    private var monthStride: Double { cellSize + monthPadding }
    /// Leading inset applied to the scroll content (`.padding(.horizontal, 4)`).
    private let leadingPadding: Double = 4

    private var months: [Date] {
        let cal = Calendar.current
        guard
            let start = cal.dateInterval(of: .month, for: startMonth)?.start,
            let end = cal.dateInterval(of: .month, for: endMonth)?.start
        else { return [] }
        var result: [Date] = []
        var cursor = start
        while cursor <= end {
            result.append(cursor)
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if displayLegend {legend}
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: monthPadding) {
                    ForEach(months, id: \.self) { month in
                        MonthGridView(
                            month: month,
                            filledDays: filledDays,
                            falseDays: falseDays,
                            tint: tint,
                            selectedDate: $selectedDate
                        )
                        .frame(width: cellSize)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            .defaultScrollAnchor(.trailing)
            .contentMargins(.trailing, 32, for: .scrollContent)
            .scrollPositionIfAvailable(scrolledMonth)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.x
            } action: { _, offsetX in
                guard let onMonthProgress, !months.isEmpty else { return }
                let raw = (Double(offsetX) - leadingPadding) / monthStride
                let clamped = min(max(raw, 0), Double(months.count - 1))
                onMonthProgress(clamped)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedDate)
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(filled: true, label: trueLabel)
            legendItem(filled: false, label: falseLabel)
            Spacer()
        }
    }

    private func legendItem(filled: Bool, label: String) -> some View {
        HStack(spacing: 6) {
            Group {
                if filled {
                    Circle().fill(tint)
                } else {
                    Circle().fill(Color.secondary.opacity(0.35))
                }
            }
            .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Scroll position helper

extension View {
    /// Applies `.scrollPosition(id:)` only when a binding is supplied, so
    /// callers that don't track the aligned month keep their default anchor.
    @ViewBuilder
    fileprivate func scrollPositionIfAvailable(
        _ binding: Binding<Date?>?
    ) -> some View {
        if let binding {
            self.scrollPosition(id: binding)
        } else {
            self
        }
    }
}

// MARK: - Month grid

private let weekdaySymbols: [String] = {
    let cal = Calendar.current
    let symbols = cal.veryShortStandaloneWeekdaySymbols
    let offset = cal.firstWeekday - 1
    return Array(symbols[offset...] + symbols[..<offset])
}()

private struct MonthGridView: View {
    let month: Date
    let filledDays: Set<Date>
    let falseDays: Set<Date>
    let tint: Color
    @Binding var selectedDate: Date?

    private var cells: [Date?] {
        let cal = Calendar.current
        guard
            let interval = cal.dateInterval(of: .month, for: month),
            let dayRange = cal.range(of: .day, in: .month, for: month)
        else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            result.append(cal.date(byAdding: .day, value: day - 1, to: interval.start))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(month.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(weekdaySymbols.indices, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                spacing: 6
            ) {
                ForEach(cells.indices, id: \.self) { i in
                    if let date = cells[i] {
                        let isFuture = Calendar.current.startOfDay(for: date)
                            > Calendar.current.startOfDay(for: Date())
                        DayCell(
                            date: date,
                            isFilled: filledDays.contains(Calendar.current.startOfDay(for: date)),
                            isFalse: falseDays.contains(Calendar.current.startOfDay(for: date)),
                            isSelected: isSelected(date),
                            isToday: Calendar.current.isDateInToday(date),
                            isFuture: isFuture,
                            tint: tint
                        )
                        .onTapGesture { selectedDate = date }
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let sel = selectedDate else { return false }
        return Calendar.current.isDate(sel, inSameDayAs: date)
    }
}

private struct DayCell: View {
    let date: Date
    let isFilled: Bool
    let isFalse: Bool
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint, lineWidth: isSelected ? 1.5 : 0)

            Group {
                if isFilled {
                    Circle().fill(tint)
                } else if isFalse {
                    Circle().fill(Color.secondary.opacity(0.35))
                } else {
                    Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                }
            }
            .padding(isSelected ? 3 : 0)

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption)
                .fontWeight(isFilled || isFalse || isToday ? .semibold : .regular)
                .foregroundStyle(isFilled || isFalse ? Color.white : .primary)
        }
        .opacity(isFuture ? 0.15 : 1)
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Circle())
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

#Preview {
    struct Demo: View {
        @State var selected: Date? = Date()
        var body: some View {
            let cal = Calendar.current
            let today = Date()
            let days = (0..<60)
                .compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
                .map { cal.startOfDay(for: $0) }
            let filled = Set(days.filter { _ in Bool.random() })
            let falseDays = Set(days.filter { !filled.contains($0) && Bool.random() })
            let start = cal.date(byAdding: .month, value: -5, to: today) ?? today
            return BinaryCalendarView(
                filledDays: filled,
                falseDays: falseDays,
                startMonth: start,
                endMonth: today,
                tint: .teal,
                trueLabel: "Done",
                falseLabel: "Rest",
                selectedDate: $selected
            )
            .padding(.vertical)
        }
    }
    return Demo()
}
