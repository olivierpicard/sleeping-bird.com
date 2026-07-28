//
//  CalendarDayCell.swift
//  ArperBird
//
//  The chrome of a single day in a scrolling calendar — everything that is
//  identical across metric types: the numeral, the selection ring, today/future
//  treatment, and the square aspect. The *fill* behind the numeral (a tinted
//  disc, an empty stroke, a category pie, …) is injected by the caller, so this
//  view carries no knowledge of what a day "means" for any given metric.
//
//  Pair with `CalendarScrollView`, which computes each day's context
//  (selected / today / future) and hands it to the cell.
//

import SwiftUI

struct CalendarDayCell<Fill: View>: View {
    let date: Date
    /// Tints the outline ring and shrinks the fill inside it.
    var isSelected: Bool = false
    /// Emphasizes the numeral even without data (matches the old "today" bold).
    var isToday: Bool = false
    /// Dims the whole cell — used for days that haven't happened yet.
    var isFuture: Bool = false
    /// Color of the outline ring when the day is selected.
    var tint: Color = .accentColor
    /// Whether the day has a logged entry. Draws the numeral's backing disc and
    /// renders the numeral semibold, so logged days read heavier than empty ones.
    var hasData: Bool = false
    /// Numeral color. Defaults to `.primary` — legible over the backing disc for
    /// every metric type.
    var numeralColor: Color = .primary
    /// Called when "Add a note" is chosen from the cell's long-press menu.
    var onAddNote: (() -> Void)? = nil
    /// Called when "Delete notes" is chosen from the cell's long-press menu.
    /// The caller decides whether the day actually has anything to delete.
    var onDeleteNotes: (() -> Void)? = nil
    /// The visual behind the numeral. Injected per metric type.
    @ViewBuilder var fill: () -> Fill

    /// Backing-disc diameter as a fraction of the cell, sized off the cell so it
    /// stays constant whether the day is one or two digits.
    private let backingScale: Double = 0.6

    var body: some View {
        cellContent
            .contentShape(Circle())
            .animation(.snappy(duration: 0.2), value: isSelected)
            .contextMenu {
                Button {
                    onAddNote?()
                } label: {
                    Label("Add a note", systemImage: "note.text.badge.plus")
                }
                Button(role: .destructive) {
                    onDeleteNotes?()
                } label: {
                    Label("Delete notes", systemImage: "trash")
                }
            } preview: {
                cellContent
                    .frame(width: 60, height: 60)
            }
            // Forces a distinct identity per day. Without it, the List's
            // lazy row/grid recycling can pin the context-menu interaction
            // to whichever cell was created first, so every long press
            // shows the same (wrong) day's menu and preview.
            .id(date)
    }

    /// The cell's plain visuals, with no interaction modifiers — reused both
    /// as the live cell and as the `.contextMenu` preview, so the lift-off
    /// snapshots just this day rather than the enclosing List row (which,
    /// without an explicit preview, is what UIKit's context-menu interaction
    /// falls back to snapshotting).
    private var cellContent: some View {
        GeometryReader { geo in
            ZStack {
                // The single outline: tint when selected, a gray "no entry" ring
                // for empty days, nothing behind a day that has its own fill.
                Circle()
                    .strokeBorder(outlineColor, lineWidth: outlineWidth)

                fill()
                    .padding(isSelected ? 3 : 0)

                numeral(cell: geo.size.width)
            }
        }
        .opacity(isFuture ? 0.35 : 1)
        .aspectRatio(1, contentMode: .fit)
    }

    /// The day's single outline color: the selection tint takes priority, then a
    /// muted "no entry" ring for empty days, otherwise none (the fill's own disc
    /// is the edge).
    private var outlineColor: Color {
        if isSelected { return tint }
        if !hasData { return Color.secondary.opacity(0.3) }
        return .clear
    }

    private var outlineWidth: Double { isSelected ? 1.5 : 1 }

    @ViewBuilder
    private func numeral(cell: Double) -> some View {
        ZStack {
            // A fixed-size solid disc sits behind the numeral on days that have
            // data, giving it a uniform base over the fill. Empty days skip it
            // so the numeral reads directly on the background.
            if hasData {
                Circle()
                    .fill(.background.opacity(0.9))
                    .frame(
                        width: cell * backingScale,
                        height: cell * backingScale
                    )
            }

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption)
                .fontWeight(hasData || isToday ? .semibold : .regular)
                .foregroundStyle(numeralColor)
        }
    }
}

#Preview("Fills") {
    let tint = Color.teal
    return LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
        spacing: 8
    ) {
        // Empty
        CalendarDayCell(date: Date(), tint: tint) {
            Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
        }
        // Solid tinted (binary "true" / logged)
        CalendarDayCell(date: Date(), tint: tint, hasData: true) {
            Circle().fill(tint)
        }
        // Solid muted (binary "false")
        CalendarDayCell(date: Date(), tint: tint, hasData: true) {
            Circle().fill(Color.secondary.opacity(0.35))
        }
        // Selected
        CalendarDayCell(
            date: Date(), isSelected: true, tint: tint, hasData: true
        ) {
            Circle().fill(tint)
        }
        // Future
        CalendarDayCell(date: Date(), isFuture: true, tint: tint) {
            Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
        }
        // Category-style: arbitrary busy fill
        CalendarDayCell(date: Date(), tint: tint, hasData: true) {
            Circle().fill(
                AngularGradient(
                    colors: [.orange, .blue, .green],
                    center: .center
                )
            )
        }
    }
    .padding()
}
