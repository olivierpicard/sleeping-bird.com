//
//  BadgeRow.swift
//  ArperBird
//
//  Created by Olivier Picard on 07/05/2026.
//

import SwiftUI

struct BadgesStackView: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Already-localized labels — resolved `String`s rather than
    /// `LocalizedStringKey`, since suggestion chips compose theirs from a
    /// localized name plus an emoji.
    let badges: [String]
    let innerPadding: Double
    let borderThickness: Double
    let borderColor: Color
    let cornerRadius: Double
    /// How wrapped rows sit in the available width — passed through to the
    /// underlying `WrappingHStack` (see its `alignment` doc).
    let alignment: HorizontalAlignment
    /// Hard cap on rows; chips that would spill past it are hidden entirely.
    /// `nil` means unbounded.
    let maxRows: Int?
    let onTap: (Int) -> Void

    init(
        badges: [String],
        innerPadding: Double = 8,
        borderThickness: Double = 1,
        borderColor: Color = Color.gray,
        cornerRadius: Double = 16,
        alignment: HorizontalAlignment = .leading,
        maxRows: Int? = nil,
        onTap: @escaping (Int) -> Void
    ) {
        self.badges = badges
        self.innerPadding = innerPadding
        self.borderThickness = borderThickness
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.alignment = alignment
        self.maxRows = maxRows
        self.onTap = onTap
    }

    var body: some View {
        WrappingHStack(alignment: alignment, hSpacing: 13, vSpacing: 13, maxRows: maxRows) {
            ForEach(badges.indices, id: \.self) { index in
                Button(action: { onTap(index) }) {
                    Text(badges[index])
                        .padding(.all, innerPadding)
                        .padding(.horizontal, 5)
                        .background {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(fillColor)
                                .stroke(borderColor, lineWidth: borderThickness)
                        }
                }
                .buttonStyle(.plain)
            }
        }

    }
    
    private var fillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.2)
            : Color.white.opacity(0.6)
    }
}

#Preview {
    BadgesStackView(
        badges: [
            "Water",
            "Sleeps",
            "Pain",
            "Mood",
            "Relax Time",
            "Coffee ☕️",
            "Meat ate",
            "Car cost",
        ],
        onTap: { _ in }
    )
}
