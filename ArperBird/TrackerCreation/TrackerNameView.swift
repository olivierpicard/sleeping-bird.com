//
//  TrackerNameView.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import SwiftUI

struct TrackerNameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var onNext: (String) -> Void = { _ in }
    /// The tracker's raw color, corrected locally via `mainColor` for the
    /// text-bearing "Next" button; the card preview above uses it raw.
    let color: Color

    @State private var name: String
    @State private var chart = NoDataMiniChart()

    private var mainColor: Color { color.readableControlTint(in: colorScheme) }

    /// `initialName` pre-fills the field — non-empty when the flow was seeded
    /// from a suggestion chip, or when the step is re-shown after a pop.
    init(
        initialName: String = "",
        color: Color,
        onNext: @escaping (String) -> Void = { _ in }
    ) {
        _name = State(initialValue: initialName)
        self.color = color
        self.onNext = onNext
    }
    @FocusState private var isNameFocused: Bool

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack {
            MetricView(
                mainColor: color,
                header: {
                    MetricHeaderEditingView(
                        emoji: "🫥",
                        mainColor: color,
                        title: $name,
                        placeholder: "Tracker name",
                        focus: $isNameFocused
                    )
                },
                chart: chart
            )
            .padding()
            Spacer()

            Button(action: { onNext(name) }) {
                // Distinct key: the shared "Continue" key is mapped to "Subscribe" by the paywall.
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .tint(mainColor)
            .disabled(!isNameValid)
            .padding()
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                isNameFocused = true
            }
        }
        .trackScreen("ManualTrackerCreationName")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("What is the tracker name ?")
        .navigationBarTitleDisplayMode(.large)
    }

}

#Preview {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerNameView(color: .accent)
        }
    }
    .presentationDetents([.large])
}
