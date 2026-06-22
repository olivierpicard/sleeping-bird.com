//
//  MetricHeaderEmoji.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import SwiftUI

/// The emoji "chip" shared by every metric header.
struct MetricHeaderEmoji: View {
    let emoji: String
    let mainColor: Color

    var size: CGFloat = 52

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.6))
            .frame(width: size, height: size)
            .background {
                mainColor.opacity(0.03)
                    .background(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(mainColor.opacity(0.4), lineWidth: 1)
            )
    }
}

#Preview {
    MetricHeaderEmoji(emoji: "👟", mainColor: .green)
        .padding()
}
