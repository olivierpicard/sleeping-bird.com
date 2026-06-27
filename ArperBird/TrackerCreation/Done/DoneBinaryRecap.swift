//
//  DoneBinaryRecap.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The binary path's reveal recap: a yes/no tracker has nothing to tune from the
/// reveal, so this is a single static line and no chips. A dumb view — it owns
/// its own wording and nothing else.
struct DoneBinaryRecap: View {
    var body: some View {
        DoneRecapText("Track yes or no each day")
    }
}

#Preview {
    DoneBinaryRecap()
}
