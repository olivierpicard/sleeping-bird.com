//
//  TrackerDateLoadingView.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/06/2026.
//

import SwiftUI

/// The step that follows naming on the `date` path. It hands the tracker name
/// to `EmojiAiCompletion` (via the shared `TrackerCreationModel`), which fills in
/// a matching emoji, then advances straight to the reveal — a date tracker needs
/// nothing else from the AI. The model memoizes the fetch, so reappearing after a
/// pop reuses the result instead of re-triggering the AI. Mirrors
/// `TrackerBinaryLoadingView`.
struct TrackerDateLoadingView: View {
    /// The flow's shared state. The view asks it to load and reads `datePhase`
    /// to decide between the spinner, the retry state, and advancing.
    let model: TrackerCreationModel
    /// Called once the emoji has loaded. The enclosing `TrackerCreationFlow` swaps
    /// this transient screen out of the nav path so "back" from the reveal returns
    /// to naming, not to this spinner.
    var onLoaded: () -> Void

    var body: some View {
        VStack {
            Spacer()
            switch model.datePhase {
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
        .trackScreen("ManualTrackerCreationDateLoading")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Setting things up")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Asks the model to load (a no-op once it already has, so a pop-back never
    /// re-triggers the AI), then advances if it succeeded.
    @MainActor
    private func load() async {
        await model.loadDateEmojiIfNeeded()
        if model.datePhase == .loaded {
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
        model.name = "Last haircut"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerDateLoadingView(model: model) {}
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
        model.name = "Last haircut"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerDateLoadingView(model: model) {}
        }
    }
    .presentationDetents([.large])
}
