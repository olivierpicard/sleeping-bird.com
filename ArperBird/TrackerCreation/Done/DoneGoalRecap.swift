//
//  DoneGoalRecap.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The goal path's reveal recap: a single line stating the daily goal and its
/// unit. No chips — the goal and unit are chosen on the earlier goal steps. A
/// dumb view: it owns the wording of its own line.
struct DoneGoalRecap: View {
    /// The daily goal value.
    let goalValue: Double
    /// The goal's unit label, e.g. "glasses".
    let unit: String

    private var recap: LocalizedStringKey {
        "Goal: \(goalValue.formatted(.number)) \(unit) per day"
    }

    var body: some View {
        DoneRecapText(recap)
    }
}

#Preview {
    DoneGoalRecap(goalValue: 8, unit: "glasses")
}
