//
//  WrappingHStack.swift
//  ArperBird
//
//  Created by Olivier Picard on 08/05/2026.
//

import SwiftUI

struct WrappingHStack: Layout {
    /// How each wrapped row is positioned within the available width. Defaults to
    /// `.leading`; `.center` offsets every row so the run of items is centered —
    /// handy for a short row of chips that should re-center as it wraps.
    var alignment: HorizontalAlignment = .leading
    var hSpacing: CGFloat = 15
    var vSpacing: CGFloat = 15
    /// Hard cap on the number of rows. Any item that would wrap onto a row beyond
    /// this limit is not shown at all — it's parked off-screen rather than
    /// partially spilling. `nil` means unbounded.
    var maxRows: Int? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rowWidths(maxWidth: maxWidth, subviews: subviews)
        let visibleRows = maxRows.map { Array(rows.prefix($0)) } ?? rows

        var height: CGFloat = 0
        var totalWidth: CGFloat = 0
        for (index, row) in visibleRows.enumerated() where !row.isEmpty {
            let rowWidth =
                row.reduce(0) { $0 + $1.width }
                + hSpacing * CGFloat(row.count - 1)
            totalWidth = max(totalWidth, rowWidth)
            height += row.reduce(0) { max($0, $1.height) }
            if index < visibleRows.count - 1 { height += vSpacing }
        }

        return CGSize(width: proposal.width ?? totalWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width

        // Group subviews into rows first, so each completed row's total width is
        // known up front — that's what lets a non-leading alignment offset the
        // whole row rather than placing items one-by-one from the left edge.
        var rows: [[(subview: LayoutSubview, size: CGSize)]] = [[]]
        var x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append((subview, size))
            x += size.width + hSpacing
        }

        var y = bounds.minY
        for (rowIndex, row) in rows.enumerated() where !row.isEmpty {
            // Rows past the cap are hidden: collapse them to zero and park them
            // far (but finitely — infinities get clamped back on-screen) off the
            // top-left so they neither render nor take part in the layout.
            if let maxRows, rowIndex >= maxRows {
                for item in row {
                    item.subview.place(
                        at: CGPoint(x: -100_000, y: -100_000),
                        proposal: ProposedViewSize(width: 0, height: 0)
                    )
                }
                continue
            }

            let rowWidth =
                row.reduce(0) { $0 + $1.size.width }
                + hSpacing * CGFloat(row.count - 1)
            let rowHeight = row.reduce(0) { max($0, $1.size.height) }

            // Offset the row's start so it sits leading / centered / trailing.
            var rowX = bounds.minX
            if alignment == .center {
                rowX += (maxWidth - rowWidth) / 2
            } else if alignment == .trailing {
                rowX += maxWidth - rowWidth
            }

            for item in row {
                item.subview.place(
                    at: CGPoint(x: rowX, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                rowX += item.size.width + hSpacing
            }
            y += rowHeight + vSpacing
        }
    }

    /// Groups subview sizes into wrapped rows for the given width — the shared
    /// measurement `sizeThatFits` needs to honor `maxRows`.
    private func rowWidths(maxWidth: CGFloat, subviews: Subviews) -> [[CGSize]] {
        var rows: [[CGSize]] = [[]]
        var x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(size)
            x += size.width + hSpacing
        }
        return rows
    }
}
