//
//  MetricStatBadge.swift
//  ArperBird
//
//  Created by Olivier Picard on 10/08/2026.
//

import SwiftUI

/// The four glanceable states a metric's trend badge can show. Each case
/// carries its own raw number — `MetricStatBadge` composes and localizes the
/// text itself, so callers never build display strings by hand.
enum MetricStatKind {
    case increase(percent: Int)
    case decrease(percent: Int)
    case streak(days: Int)
    case missing(days: Int)
}

/// A small pill under a metric's value summarizing its recent trend, e.g.
/// "+50%" or "3d streak". Entirely on the tracker's own `mainColor` — no
/// red/green good/bad judgment, since whether an increase is "good" depends
/// on the metric (steps vs. coffee). States are told apart by icon shape
/// alone (up/down triangle, bolt, moon), not color.
struct MetricStatBadge: View {
    let kind: MetricStatKind
    let mainColor: Color

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
