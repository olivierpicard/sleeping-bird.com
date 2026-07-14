//
//  TrackerDurationLoadingView.swift
//  ArperBird
//
//  Created by Olivier Picard on 25/06/2026.
//

import SwiftUI

/// The step that follows naming on the `duration` path. It hands the tracker name
/// to `EmojiAiCompletion` (via the shared `TrackerCreationModel`), which fills in
/// a matching emoji, then advances straight to the reveal — the duration wheel
/// logs a fixed h/m/s, so it needs nothing else from the AI. The model memoizes
/// the fetch, so reappearing after a pop reuses the result instead of
/// re-triggering the AI. Mirrors `TrackerBinaryLoadingView`.
struct TrackerDurationLoadingView: View {
    /// The flow's shared state. The view asks it to load and reads `durationPhase`
    /// to decide between the spinner, the retry state, and advancing.
    let model: TrackerCreationModel
    /// Called once the duration config has loaded. The enclosing
    /// `TrackerCreationFlow` swaps this transient screen out of the nav path so
    /// "back" from the next screen returns to naming, not to this spinner.
    var onLoaded: () -> Void

    var body: some View {
        VStack {
            Spacer()
            switch model.durationPhase {
            case .failed:
                ContentUnavailableView {
                    Label("Couldn't set up your tracker", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(action: { Task { await load() } }) {
                        Text("Try again")
                    }
                }
            default:
                ProgressView("Setting up your tracker…")
                    .tint(nil)
            }
            Spacer()
        }
        .task { await load() }
        .trackScreen("ManualTrackerCreationDurationLoading")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Setting things up")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Asks the model to load (a no-op once it already has, so a pop-back never
    /// re-triggers the AI), then advances if it succeeded.
    @MainActor
    private func load() async {
        await model.loadDurationEmojiIfNeeded()
        if model.durationPhase == .loaded {
            onLoaded()
        }
    }
}

#Preview {
    @Previewable @State var showSheet = true
    @Previewable @State var model: TrackerCreationModel = {
        let model = TrackerCreationModel(
            generateEmoji: { try await EmojiAiCompletion().generateFake(for: $0) }
        )
        model.name = "Workout"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerDurationLoadingView(model: model) {}
        }
    }
    .presentationDetents([.large])
}

#Preview("Failure") {
    @Previewable @State var showSheet = true
    @Previewable @State var model: TrackerCreationModel = {
        let model = TrackerCreationModel(
            generateEmoji: { _ in throw URLError(.notConnectedToInternet) }
        )
        model.name = "Workout"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerDurationLoadingView(model: model) {}
        }
    }
    .presentationDetents([.large])
}
 
