//
//  MetricStatBadge.swift
//  ArperBird
//
//  Created by Olivier Picard on 10/08/2026.
//

import SwiftUI

/// A small pill under a metric's value summarizing its recent trend, e.g.
/// "+50%" or "3d streak". Entirely on the tracker's own `mainColor` — no
/// red/green good/bad judgment, since whether an increase is "good" depends
/// on the metric (steps vs. coffee). States are told apart by icon shape
/// alone (up/down triangle, bolt, moon), not color.
struct MetricStatBadge: View {
    /// `compact` is the card's terse pill ("+50%"); `detailed` spells out the
    /// comparison for the metric detail screen ("+50% vs. the previous 7
    /// days"), where there's room and the extra context is worth it.
    enum Style {
        case compact
        case detailed
    }

    let kind: MetricStatKind
    let mainColor: Color
    var style: Style = .compact

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(mainColor)
            Text(text)
        }
        .font(.caption)
        .fontWeight(.bold)
        .foregroundStyle(mainColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(mainColor.opacity(0.15), in: Capsule())
    }

    private var symbolName: String {
        switch kind {
        case .increase: "arrowtriangle.up.fill"
        case .decrease: "arrowtriangle.down.fill"
        case .streak: "bolt.fill"
        case .missing: "moon.fill"
        }
    }

    private var text: String {
        switch style {
        case .compact:
            switch kind {
            case .increase(let percent):
                String(localized: "+\(percent)%")
            case .decrease(let percent):
                String(localized: "-\(percent)%")
            case .streak(let days):
                String(localized: "\(days)d streak")
            case .missing(let days):
                String(localized: "\(days)d idle")
            }
        case .detailed:
            switch kind {
            case .increase(let percent):
                String(localized: "+\(percent)% vs. the previous 7 days")
            case .decrease(let percent):
                String(localized: "-\(percent)% vs. the previous 7 days")
            case .streak(let days):
                String(localized: "On a \(days)-day streak")
            case .missing(let days):
                String(localized: "Nothing logged in \(days) days")
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        MetricStatBadge(kind: .increase(percent: 50), mainColor: .green)
        MetricStatBadge(kind: .decrease(percent: 12), mainColor: .orange)
        MetricStatBadge(kind: .streak(days: 3), mainColor: .pink)
        MetricStatBadge(kind: .missing(days: 3), mainColor: .blue)
    }
    .padding()
}

#Preview("Detailed") {
    VStack(alignment: .leading, spacing: 12) {
        MetricStatBadge(
            kind: .increase(percent: 50),
            mainColor: .green,
            style: .detailed
        )
        MetricStatBadge(
            kind: .decrease(percent: 12),
            mainColor: .orange,
            style: .detailed
        )
        MetricStatBadge(
            kind: .streak(days: 3),
            mainColor: .pink,
            style: .detailed
        )
        MetricStatBadge(
            kind: .missing(days: 3),
            mainColor: .blue,
            style: .detailed
        )
    }
    .padding()
}
