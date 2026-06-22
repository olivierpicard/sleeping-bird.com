//
//  MetricHeaderTextView.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import SwiftUI
import TipKit

/// The standard, read-only metric header: emoji + title/value + an "add entry" button.
struct MetricHeaderTextView: View {
    private let addEntryTip = AddEntryTip()

    let title: String
    let emoji: String
    let value: String
    let mainColor: Color
    var onAddTapped: () -> Void = {}
    var showAddButton = true
    
    @State private var feedbackTrigger = false

    var body: some View {
        HStack {
            MetricHeaderEmoji(emoji: emoji, mainColor: mainColor)

            VStack(alignment: .leading, spacing: 0) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Spacer()

            
            if showAddButton {
                Button(action: {
                    feedbackTrigger.toggle()
                    addEntryTip.invalidate(reason: .actionPerformed)
                    onAddTapped()
                }) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(mainColor)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .tint(mainColor.mix(with: .gray, by: 0.5))
                .popoverTip(addEntryTip, arrowEdge: .top)
                .sensoryFeedback(
                    .impact(flexibility: .soft),
                    trigger: feedbackTrigger
                )
            }
        }
    }
}

#Preview {
    MetricHeaderTextView(
        title: "Daily Steps",
        emoji: "👟",
        value: "8,432",
        mainColor: .green
    )
    .padding()
}
