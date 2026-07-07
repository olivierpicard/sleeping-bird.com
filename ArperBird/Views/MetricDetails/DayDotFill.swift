//
//  DayDotFill.swift
//  ArperBird
//
//  The interior fill shared by every non-category calendar — binary, date,
//  number, and duration. A day is one of three states: a solid tinted disc (a
//  "true" or logged day), a solid muted disc (a binary "false" day), or nothing
//  (no entry). Number / date / duration only ever use `.filled` and `.empty`;
//  binary adds `.muted` for its false label.
//
//  This draws only the interior — the day's outline (the hollow "no entry" ring
//  and the selection ring) is owned by the enclosing `CalendarDayCell`, so an
//  empty day renders no fill at all here.
//

import SwiftUI

struct DayDotFill: View {
    enum Style {
        /// Solid tint — a logged day, or a binary "true".
        case filled
        /// Solid muted disc — a binary "false" day.
        case muted
        /// No interior — an empty day; `CalendarDayCell` draws its outline.
        case empty
    }

    let style: Style
    var tint: Color

    var body: some View {
        switch style {
        case .filled:
            Circle().fill(tint)
        case .muted:
            Circle().fill(Color.secondary.opacity(0.35))
        case .empty:
            EmptyView()
        }
    }
}

#Preview("In cell") {
    let tint = Color.teal
    return LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
        spacing: 8
    ) {
        CalendarDayCell(date: Date(), tint: tint, hasData: true) {
            DayDotFill(style: .filled, tint: tint)
        }
        CalendarDayCell(date: Date(), tint: tint, hasData: true) {
            DayDotFill(style: .muted, tint: tint)
        }
        CalendarDayCell(date: Date(), tint: tint) {
            DayDotFill(style: .empty, tint: tint)
        }
        CalendarDayCell(
            date: Date(),
            isSelected: true,
            tint: tint,
            hasData: false
        ) {
            DayDotFill(style: .filled, tint: tint)
        }
        
        // Future — no data
        CalendarDayCell(date: Date(), isFuture: true, tint: tint) {
            DayDotFill(style: .empty, tint: tint)
        }
        // Today — no data
        CalendarDayCell(date: Date(), isToday: true, tint: tint) {
            DayDotFill(style: .empty, tint: tint)
        }
        // Selected today — no data
        CalendarDayCell(
            date: Date(), isSelected: true, isToday: true, tint: tint
        ) {
            DayDotFill(style: .empty, tint: tint)
        }
    }
    .padding()
}
