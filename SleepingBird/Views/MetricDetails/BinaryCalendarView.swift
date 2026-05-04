//
//  BinaryCalendarView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 04/05/2026.
//

import SwiftUI

struct BinaryCalendarView: View {
    let filledDays: Set<Date>
    let startMonth: Date
    let endMonth: Date
    let tint: Color
    let trueLabel: String
    let falseLabel: String
    let cellSize: Double = 300
    let displayLegend: Bool = false
    @Binding var selectedDate: Date?

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
                LazyHStack(alignment: .top, spacing: 28) {
                    ForEach(months, id: \.self) { month in
                        MonthGridView(
                            month: month,
                            filledDays: filledDays,
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
                    Circle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                }
            }
            .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                .font(.caption2)
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
                } else {
                    Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                }
            }
            .padding(isSelected ? 3 : 0)

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption)
                .fontWeight(isFilled || isToday ? .semibold : .regular)
                .foregroundStyle(isFilled ? Color.white : .primary)
        }
        .opacity(isFuture ? 0.2 : 1)
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
            let filled: Set<Date> = Set(
                (0..<60)
                    .compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
                    .filter { _ in Bool.random() }
                    .map { cal.startOfDay(for: $0) }
            )
            let start = cal.date(byAdding: .month, value: -5, to: today) ?? today
            return BinaryCalendarView(
                filledDays: filled,
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
