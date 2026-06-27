//
//  DoneCategoryRecap.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The choices path's reveal recap: a line stating how the user picks, plus a
/// quiet, tappable chip that flips single ↔ multiple choice in place. A dumb,
/// reactive view — it derives its own wording and glyph from `allowsMultiple`,
/// and routes the flip through the injected `onToggleChoice`; it never mutates
/// anything itself.
struct DoneCategoryRecap: View {
    /// Whether the entry allows multiple selections. Drives both the recap line
    /// and the chip's label/glyph.
    let allowsMultiple: Bool
    /// How many categories the tracker carries — surfaced in the recap line.
    let count: Int
    let color: Color
    /// Invoked when the chip is tapped — the flow flips the model's
    /// `categoryAllowsMultiple`, which re-derives this recap and the card's chart
    /// (pie ↔ bar) in place.
    var onToggleChoice: () -> Void = {}

    private var recap: LocalizedStringKey {
        allowsMultiple
            ? "Pick several from \(count) categories"
            : "Pick one of \(count) categories"
    }

    private var title: LocalizedStringKey {
        allowsMultiple ? "Multiple choice" : "Single choice"
    }

    private var glyph: String {
        allowsMultiple ? "checkmark.square.fill" : "largecircle.fill.circle"
    }

    var body: some View {
        VStack(spacing: 12) {
            DoneRecapText(recap)
            choiceChip
        }
    }

    /// A tappable capsule carrying the choice glyph, its label, and a swap arrow —
    /// understated so it sits below the recap without competing with the
    /// celebration, while still reading as a control that flips the mode in place.
    private var choiceChip: some View {
        Button(action: onToggleChoice) {
            DoneChip(color: color) {
                Image(systemName: glyph)
                    .foregroundStyle(color)
                Text(title)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Switches between single and multiple choice")
    }
}

#Preview {
    @Previewable @State var multiple = false
    DoneCategoryRecap(
        allowsMultiple: multiple,
        count: 4,
        color: .pink,
        onToggleChoice: { multiple.toggle() }
    )
}
