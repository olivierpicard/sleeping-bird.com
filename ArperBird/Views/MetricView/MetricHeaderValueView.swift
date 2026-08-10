//
//  MetricHeaderValueView.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import SwiftUI
import TipKit
internal import Combine

/// The standard, read-only metric header: emoji + title/value + an "add entry" button.
struct MetricHeaderValueView: View {
    private let addEntryTip = AddEntryTip()

    let title: String
    let emoji: String
    let value: String
    /// `nil` renders no badge at all — a metric with nothing worth reporting
    /// shows none, rather than a "stable" pill that says nothing.
    var stat: MetricStatKind? = nil
    let mainColor: Color
    var onAddTapped: () -> Void = {}
    var showAddButton = true
    
    @State private var feedbackTrigger = false

    /// Half the "+" button's width, measured at layout time. The button sits
    /// flush against the trailing edge, so this is also the distance from that
    /// edge to its centre — which is where the tip's arrow has to point.
    @State private var addButtonHalfWidth: CGFloat = 20

    private let tipBackground = Color(.tertiarySystemGroupedBackground)
    private let arrowSize = CGSize(width: 22, height: 11)

    var body: some View {
        VStack(spacing: 4) {
            headerRow

            // Inline rather than `.popoverTip`: a popover installs a
            // full-screen backdrop that swallows the first tap, so the "+"
            // needed a second tap to open the editor. `TipView(_:arrowEdge:)`
            // isn't used either — its arrow is always centred, while this one
            // has to point at the "+" button.
            if showAddButton {
                TipView(addEntryTip)
                    .tint(mainColor)
                    // The bubble and its arrow are a single filled path, so
                    // there is no seam where the two meet.
                    .tipBackground(Color.clear)
                    .padding(.top, arrowSize.height)
                    .background {
                        TipBubble(
                            arrowSize: arrowSize,
                            arrowCenterFromTrailing: addButtonHalfWidth
                        )
                        .fill(tipBackground)
                    }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            MetricHeaderEmoji(emoji: emoji, mainColor: mainColor)

            VStack(alignment: .leading, spacing: 0) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                if let stat {
                    MetricStatBadge(kind: stat, mainColor: mainColor)
                        .padding(.top, 5)
                }
            }

            Spacer()

            
            if showAddButton {
                Button(action: {
                    feedbackTrigger.toggle()
                    addEntryTip.invalidate(reason: .actionPerformed)
                    onAddTapped()
                }) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(mainColor)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .tint(mainColor.mix(with: .gray, by: 0.5))
                .onGeometryChange(for: CGFloat.self) { $0.size.width / 2 } action: {
                    addButtonHalfWidth = $0
                }
                .sensoryFeedback(
                    .impact(flexibility: .soft),
                    trigger: feedbackTrigger
                )
            }
        }
    }
}

/// The tip's speech-bubble background: a rounded rectangle plus an upward arrow
/// pointing at the "+" button, as **one** path. Drawing them as two shapes left
/// a visible line where the arrow's base met the rectangle's edge.
private struct TipBubble: Shape {
    let arrowSize: CGSize
    /// Distance from the bubble's trailing edge to the arrow's apex.
    let arrowCenterFromTrailing: CGFloat

    var cornerRadius: CGFloat = 18
    /// How far below the apex the rounding starts. Kept small — any larger and
    /// the arrow turns back into a dome.
    var apexRadius: CGFloat = 2.5

    func path(in rect: CGRect) -> Path {
        var path = Path(
            roundedRect: CGRect(
                x: rect.minX,
                y: rect.minY + arrowSize.height,
                width: rect.width,
                height: rect.height - arrowSize.height
            ),
            cornerRadius: cornerRadius
        )

        let apexX = rect.maxX - arrowCenterFromTrailing
        let baseY = rect.minY + arrowSize.height
        path.move(to: CGPoint(x: apexX - arrowSize.width / 2, y: baseY))
        path.addLine(to: CGPoint(x: apexX - apexRadius, y: rect.minY + apexRadius))
        path.addQuadCurve(
            to: CGPoint(x: apexX + apexRadius, y: rect.minY + apexRadius),
            control: CGPoint(x: apexX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: apexX + arrowSize.width / 2, y: baseY))
        path.closeSubpath()

        return path
    }
}

#Preview {
    MetricHeaderValueView(
        title: "Daily Steps",
        emoji: "👟",
        value: "8,432",
        mainColor: .green
    )
    .padding()
}

#Preview("Animated updates") {
    @Previewable @State var value = 8_432

    VStack(spacing: 24) {
        MetricHeaderValueView(
            title: "Daily Steps",
            emoji: "👟",
            value: value.formatted(),
            mainColor: .green
        )

        Button("Update value") { value += .random(in: 100...2_000) }
            .buttonStyle(.borderedProminent)
    }
    .padding()
}
