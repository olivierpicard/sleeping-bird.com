//
//  MetricHeaderEmoji.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import SwiftUI

/// The emoji "chip" shared by every metric header.
///
/// When `editable` is supplied, the chip becomes tappable and brings up the
/// system emoji keyboard, writing the chosen emoji back through the binding.
struct MetricHeaderEmoji: View {
    let emoji: String
    let mainColor: Color

    var size: CGFloat = 52
    /// When non-nil, the chip is editable and edits flow back through this binding.
    var editable: Binding<String>? = nil

    var body: some View {
        content
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
            .overlay(alignment: .bottomTrailing) {
                if editable != nil {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(.white, mainColor)
                        .allowsHitTesting(false)
                        .offset(x: 4, y: 4)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let editable {
            EmojiInputField(text: editable, fontSize: size * 0.6)
        } else {
            Text(emoji)
                .font(.system(size: size * 0.6))
        }
    }
}

#Preview {
    MetricHeaderEmoji(emoji: "👟", mainColor: .green)
        .padding()
}
