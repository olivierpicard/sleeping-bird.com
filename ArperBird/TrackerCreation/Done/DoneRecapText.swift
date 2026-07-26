//
//  DoneRecapText.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The one-line recap shown under the reveal card, in the shared muted style.
/// Every path's recap view derives its own wording and renders it through this,
/// so the line changes per path while the type and tint stay identical.
struct DoneRecapText: View {
    private let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}
