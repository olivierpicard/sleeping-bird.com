//
//  DayPieFill.swift
//  ArperBird
//
//  The interior fill for a *category* calendar — a day's active choices painted
//  as an equal-wedge pie clipped to a circle. One color renders as a full disc,
//  2+ as equal wedges, and a day with no colors renders nothing (its "no entry"
//  outline is drawn by the enclosing `CalendarDayCell`, like `DayDotFill.empty`).
//  A hairline traces the disc and the wedge seams so pale fills read against the
//  background without altering the color itself.
//
//  Injected as the `fill` of a `CalendarDayCell`, which draws the numeral,
//  backing disc, and the outline / selection ring on top.
//

import SwiftUI

struct DayPieFill: View {
    /// The day's active choice colors, in stable list order. Empty = no entry.
    let colors: [Color]

    /// Scheme-adaptive hairline; dark on light backgrounds, light on dark.
    private let outline = Color.primary.opacity(0.15)
    private let lineWidth: CGFloat = 0.75

    var body: some View {
        if colors.isEmpty {
            EmptyView()
        } else {
            pie
        }
    }

    private var pie: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let sweep = 360.0 / Double(colors.count)
            for (i, color) in colors.enumerated() {
                var path = Path()
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-90 + sweep * Double(i)),
                    endAngle: .degrees(-90 + sweep * Double(i + 1)),
                    clockwise: false
                )
                path.closeSubpath()
                context.fill(path, with: .color(color))
            }

            // Outer ring — inset by half the stroke so the clip doesn't shave
            // off its outer edge. This is what gives a pale disc a visible edge.
            let ringRadius = radius - lineWidth / 2
            let ring = Path(
                ellipseIn: CGRect(
                    x: center.x - ringRadius,
                    y: center.y - ringRadius,
                    width: ringRadius * 2,
                    height: ringRadius * 2
                )
            )
            context.stroke(ring, with: .color(outline), lineWidth: lineWidth)

            // Wedge seams — only when there's more than one color, so a single
            // full-circle wedge doesn't get a stray radial spoke.
            if colors.count > 1 {
                for i in colors.indices {
                    let angle = Angle.degrees(-90 + sweep * Double(i)).radians
                    var seam = Path()
                    seam.move(to: center)
                    seam.addLine(
                        to: CGPoint(
                            x: center.x + radius * cos(angle),
                            y: center.y + radius * sin(angle)
                        )
                    )
                    context.stroke(seam, with: .color(outline), lineWidth: lineWidth)
                }
            }
        }
        .clipShape(Circle())
    }
}

#Preview("In cell") {
    let tint = Color.teal
    let palette: [Color] = [.orange, .blue, .green, .pink]
    return LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
        spacing: 8
    ) {
        // Single choice — full disc
        CalendarDayCell(date: Date(), tint: tint, hasData: true) {
            DayPieFill(colors: [palette[0]])
        }
        // Two choices
        CalendarDayCell(date: Date(), tint: tint, hasData: true) {
            DayPieFill(colors: Array(palette.prefix(2)))
        }
        // Four choices
        CalendarDayCell(date: Date(), tint: tint, hasData: true) {
            DayPieFill(colors: palette)
        }
        // No entry
        CalendarDayCell(date: Date(), tint: tint) {
            DayPieFill(colors: [])
        }

        // Selected — pie shrinks inside the ring
        CalendarDayCell(
            date: Date(), isSelected: true, tint: tint, hasData: true
        ) {
            DayPieFill(colors: Array(palette.prefix(3)))
        }
        // Future — no data
        CalendarDayCell(date: Date(), isFuture: true, tint: tint) {
            DayPieFill(colors: [])
        }
        // Today — no data
        CalendarDayCell(date: Date(), isToday: true, tint: tint) {
            DayPieFill(colors: [])
        }
    }
    .padding()
}
