//
//  MetricHeaderValueView.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import SwiftUI
import TipKit
internal import Combine

/// The standard, read-only metric header: emoji + title/value + an "add entry" button.
struct MetricHeaderValueView: View {
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
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
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
    MetricHeaderValueView(
        title: "Daily Steps",
        emoji: "👟",
        value: "8,432",
        mainColor: .green
    )
    .padding()
}

#Preview("Animated updates") {
    @Previewable @State var value = 8_432

    VStack(spacing: 24) {
        MetricHeaderValueView(
            title: "Daily Steps",
            emoji: "👟",
            value: value.formatted(),
            mainColor: .green
        )

        Button("Update value") { value += .random(in: 100...2_000) }
            .buttonStyle(.borderedProminent)
    }
    .padding()
}
