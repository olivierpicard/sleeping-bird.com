//
//  DoneDurationRecap.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

struct DoneDurationRecap: View {
    let maxSeconds: Int
    let color: Color
    let onUpdate: (Int) -> Void

    @State private var isEditing = false

    private var formatted: String {
        Duration.seconds(max(0, maxSeconds))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }

    var body: some View {
        Button(action: { isEditing = true }) {
            DoneChip(color: color) {
                Image(systemName: "clock")
                    .foregroundStyle(color)
                Text("Max")
                Text(formatted)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isEditing) {
            DurationMaxEditor(maxSeconds: maxSeconds, color: color) { newSeconds in
                onUpdate(newSeconds)
                isEditing = false
            }
        }
    }
}

#Preview {
    @Previewable @State var maxSeconds = 2 * 3600
    DoneDurationRecap(maxSeconds: maxSeconds, color: .teal, onUpdate: { maxSeconds = $0 })
}
