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

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + vSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - hSpacing)
        }

        return CGSize(width: proposal.width ?? totalWidth, height: y + rowHeight)
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
        for row in rows where !row.isEmpty {
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
}
