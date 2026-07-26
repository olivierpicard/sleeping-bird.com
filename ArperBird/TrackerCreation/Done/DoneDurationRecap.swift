//
//  DoneDurationRecap.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The duration path's reveal recap: the wheel logs a fixed h/m/s, so there's
/// nothing to tune from the reveal — a single static line and no chips. A dumb
/// view — it owns its own wording and nothing else. Mirrors `DoneBinaryRecap`.
struct DoneDurationRecap: View {
    var body: some View {
        DoneRecapText("Track how long it lasts")
    }
}

#Preview {
    DoneDurationRecap()
}
