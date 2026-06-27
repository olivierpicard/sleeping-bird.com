//
//  DoneDateRecap.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The date path's reveal recap: a date tracker needs nothing tuned from the
/// reveal, so this is a single static line and no chips. A dumb view — it owns
/// its own wording and nothing else.
struct DoneDateRecap: View {
    var body: some View {
        DoneRecapText("Save a date on calendar")
    }
}

#Preview {
    DoneDateRecap()
}
