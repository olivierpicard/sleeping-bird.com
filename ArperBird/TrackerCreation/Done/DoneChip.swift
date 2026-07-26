//
//  DoneChip.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The shared capsule chrome behind every reveal chip — soft fill, a hairline
/// tint stroke, secondary small type — so the choice and number-facet chips
/// stay visually identical across the per-path recap views that use them.
struct DoneChip<Content: View>: View {
    let color: Color
    private let content: Content

    init(color: Color, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 6) { content }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.quaternary.opacity(0.5)))
            .overlay { Capsule().stroke(color.opacity(0.4), lineWidth: 1) }
    }
}
