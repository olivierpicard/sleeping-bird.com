//
//  BadgeRow.swift
//  ArperBird
//
//  Created by Olivier Picard on 07/05/2026.
//

import SwiftUI

struct BadgesStackView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let badges: [LocalizedStringKey]
    let innerPadding: Double
    let borderThickness: Double
    let borderColor: Color
    let cornerRadius: Double

    init(
        badges: [LocalizedStringKey],
        innerPadding: Double = 8,
        borderThickness: Double = 1,
        borderColor: Color = Color.gray,
        cornerRadius: Double = 16
    ) {
        self.badges = badges
        self.innerPadding = innerPadding
        self.borderThickness = borderThickness
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        WrappingHStack(hSpacing: 13, vSpacing: 13) {
            ForEach(badges.indices, id: \.self) { index in
                Text(badges[index])
                    .padding(.all, innerPadding)
                    .padding(.horizontal, 5)
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(fillColor)
                            .stroke(borderColor, lineWidth: borderThickness)
                    }

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
            "Coffee ☕️", // Translated
            "Meat ate",
            "Car cost",
        ])
}
