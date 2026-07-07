//
//  CalendarScrollView.swift
//  ArperBird
//
//  The type-agnostic scaffolding of a horizontally-scrolling month calendar:
//  the month range, the per-month day grid, the weekday header, view-aligned
//  paging, and the two-way scroll bindings (`scrolledMonth` / `onMonthProgress`)
//  that let an external month selector follow the drag. It knows nothing about
//  what a day contains — for each date it hands the caller a `CalendarDayContext`
//  (selected / today / future) and renders whatever cell the caller returns,
//  typically a `CalendarDayCell` with a metric-specific fill.
//
//  The shared scroll engine behind the binary, date, number, duration, and
//  category calendars — they reuse it and differ only in their cells.
//

import SwiftUI

/// Per-day state the shell computes so callers don't each re-derive it.
struct CalendarDayContext {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    /// The day is strictly after today (start-of-day comparison).
    let isFuture: Bool
}

struct CalendarScrollView<Cell: View>: View {
    let startMonth: Date
    let endMonth: Date
    @Binding var selectedDate: Date?

    /// Optional two-way binding to the month currently aligned in the scroll
    /// view. When provided, drives an external month selector.
    var scrolledMonth: Binding<Date?>? = nil
    /// Reports live scroll progress in month units (0 = first month, N-1 =
    /// last), updating continuously during a swipe so an external selector can
    /// follow the drag rather than only snapping at rest.
    var onMonthProgress: ((Double) -> Void)? = nil

    var cellSize: Double = 270
    var monthPadding: Double = 40

    /// Builds the cell for a given day. Return a `CalendarDayCell` (or anything).
    @ViewBuilder var cell: (CalendarDayContext) -> Cell

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
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor)
            else { break }
            cursor = next
        }
        return result
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: monthPadding) {
                ForEach(months, id: \.self) { month in
                    MonthGridView(
                        month: month,
                        selectedDate: $selectedDate,
                        showsMonthTitle: scrolledMonth == nil,
                        cell: cell
                    )
                    .frame(width: cellSize)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, leadingPadding)
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
        .sensoryFeedback(.selection, trigger: selectedDate)
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

private let calendarWeekdaySymbols: [String] = {
    let cal = Calendar.current
    let symbols = cal.veryShortStandaloneWeekdaySymbols
    let offset = cal.firstWeekday - 1
    return Array(symbols[offset...] + symbols[..<offset])
}()

private struct MonthGridView<Cell: View>: View {
    let month: Date
    @Binding var selectedDate: Date?
    /// Whether the grid shows its own month name. Off when an external month
    /// selector (driven by `scrolledMonth`) already displays it.
    let showsMonthTitle: Bool
    @ViewBuilder let cell: (CalendarDayContext) -> Cell

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
            result.append(
                cal.date(byAdding: .day, value: day - 1, to: interval.start)
            )
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsMonthTitle {
                Text(
                    month.formatted(.dateTime.month(.abbreviated)).uppercased()
                )
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                ForEach(calendarWeekdaySymbols.indices, id: \.self) { i in
                    Text(calendarWeekdaySymbols[i])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 6), count: 7
                ),
                spacing: 6
            ) {
                ForEach(cells.indices, id: \.self) { i in
                    if let date = cells[i] {
                        cell(context(for: date))
                            .onTapGesture { selectedDate = date }
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private func context(for date: Date) -> CalendarDayContext {
        let cal = Calendar.current
        let isSelected = selectedDate.map {
            cal.isDate($0, inSameDayAs: date)
        } ?? false
        let isFuture = cal.startOfDay(for: date) > cal.startOfDay(for: Date())
        return CalendarDayContext(
            date: date,
            isSelected: isSelected,
            isToday: cal.isDateInToday(date),
            isFuture: isFuture
        )
    }
}

#Preview {
    struct Demo: View {
        @State private var selected: Date? = Date()

        var body: some View {
            let cal = Calendar.current
            let today = Date()
            let logged = Set(
                (0..<60)
                    .compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
                    .map { cal.startOfDay(for: $0) }
                    .filter { _ in Bool.random() }
            )
            let start = cal.date(byAdding: .month, value: -5, to: today) ?? today
            let tint = Color.teal

            return CalendarScrollView(
                startMonth: start,
                endMonth: today,
                selectedDate: $selected
            ) { ctx in
                let isLogged = logged.contains(cal.startOfDay(for: ctx.date))
                CalendarDayCell(
                    date: ctx.date,
                    isSelected: ctx.isSelected,
                    isToday: ctx.isToday,
                    isFuture: ctx.isFuture,
                    tint: tint,
                    hasData: isLogged
                ) {
                    if isLogged {
                        Circle().fill(tint)
                    } else {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    }
                }
            }
            .frame(height: 320)
            .padding(.vertical)
        }
    }
    return Demo()
}
