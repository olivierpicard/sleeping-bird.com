//
//  DoneDurationRecap.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The duration path's reveal recap: a single line stating the upper bound the
/// user dialed in, formatted in hours and minutes. No chips — the bound is set on
/// the earlier config step. A dumb view: it owns the formatting of its own line.
struct DoneDurationRecap: View {
    /// The tracker's upper bound in seconds, as set on the duration config step.
    let maxSeconds: Int

    var body: some View {
        DoneRecapText(
            "Tracks up to \(Duration.seconds(max(0, maxSeconds)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))"
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        DoneDurationRecap(maxSeconds: 2 * 3600)
        DoneDurationRecap(maxSeconds: 90 * 60)
        DoneDurationRecap(maxSeconds: 45 * 60)
    }
}
