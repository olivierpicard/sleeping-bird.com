//
//  MetricHeaderTextView.swift
//  ArperBird
//
//  Created by Olivier Picard on 28/06/2026.
//

import SwiftUI

/// A read-only metric header that shows just the emoji + title — no value or
/// "add entry" button. The lightweight sibling of `MetricHeaderValueView`, for
/// places that only need to identify the tracker (e.g. the creation reveal).
struct MetricHeaderTextView: View {
    let title: String
    let emoji: String
    let mainColor: Color

    var body: some View {
        HStack {
            MetricHeaderEmoji(emoji: emoji, mainColor: mainColor)

            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)

            Spacer()
        }
    }
}

#Preview {
    MetricHeaderTextView(
        title: "Daily Steps",
        emoji: "👟",
        mainColor: .green
    )
    .padding()
}
