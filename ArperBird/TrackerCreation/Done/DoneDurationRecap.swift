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

    /// Formats the bound as e.g. "Tracks up to 2h" / "1h 30m" / "45m" — hours
    /// once the bound clears an hour, minutes otherwise.
    private var recap: LocalizedStringKey {
        let seconds = max(0, maxSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let text =
            hours > 0
            ? (minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h")
            : "\(minutes)m"
        return "Tracks up to \(text)"
    }

    var body: some View {
        DoneRecapText(recap)
    }
}

#Preview {
    VStack(spacing: 16) {
        DoneDurationRecap(maxSeconds: 2 * 3600)
        DoneDurationRecap(maxSeconds: 90 * 60)
        DoneDurationRecap(maxSeconds: 45 * 60)
    }
}
