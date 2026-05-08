//
//  BadgeRow.swift
//  SleepingBird
//
//  Created by Olivier Picard on 07/05/2026.
//

import SwiftUI

struct BadgesStackView: View {
    let badges: [String]
    let innerPadding: Double
    let borderThickness: Double
    let borderColor: Color
    let fillColor: Color

    init(
        badges: [String],
        innerPadding: Double = 13,
        borderThickness: Double = 1,
        borderColor: Color = Color.gray,
        fillColor: Color = Color.white.opacity(0.6)
    ) {
        self.badges = badges
        self.innerPadding = innerPadding
        self.borderThickness = borderThickness
        self.borderColor = borderColor
        self.fillColor = fillColor
    }

    var body: some View {
        WrappingHStack(hSpacing: 13, vSpacing: 13) {
            ForEach(badges, id: \.self) { item in
                Text(item)
                    .padding(.all, innerPadding)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(fillColor)
                            .stroke(borderColor, lineWidth: borderThickness)
                    }

            }
        }

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
            "Coffee",
            "Meat ate",
            "Car cost",
        ])
}
