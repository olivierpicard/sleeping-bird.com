//
//  TrackerNameView.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import SwiftUI

struct TrackerNameView: View {
    @Environment(\.dismiss) private var dismiss

    var onNext: (String) -> Void = { _ in }

    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack {
            MetricView(
                mainColor: .gray,
                header: {
                    MetricHeaderEditingView(
                        emoji: "🫥",
                        mainColor: .gray,
                        title: $name,
                        placeholder: "Tracker name",
                        focus: $isNameFocused
                    )
                },
                chart: { NoDataMiniChart() }
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
            TrackerNameView()
        }
    }
    .presentationDetents([.large])
}
