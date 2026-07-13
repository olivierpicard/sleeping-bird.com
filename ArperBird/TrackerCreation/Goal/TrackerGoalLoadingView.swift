//
//  TrackerGoalLoadingView.swift
//  ArperBird
//
//  Created by Olivier Picard on 28/06/2026.
//

import SwiftUI

/// The step that follows naming on the `goal` path. It hands the tracker name to
/// `GoalAiCompletion` (via the shared `TrackerCreationModel`), which proposes a
/// few units — each with a daily target and step — plus a shared emoji, then
/// advances to the unit list. The model memoizes the fetch, so reappearing after
/// a pop reuses the result instead of re-triggering the AI. Mirrors
/// `TrackerNumberLoadingView`.
struct TrackerGoalLoadingView: View {
    /// The flow's shared state. The view asks it to load and reads `phase` to
    /// decide between the spinner, the retry state, and advancing.
    let model: TrackerCreationModel
    /// Called once the goal suggestions have loaded. The enclosing
    /// `TrackerCreationFlow` swaps this transient screen out of the nav path so
    /// "back" from the unit list returns to naming, not to this spinner.
    var onLoaded: () -> Void

    var body: some View {
        VStack {
            Spacer()
            switch model.phase {
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
        .trackScreen("ManualTrackerCreationGoalLoading")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Setting things up")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Asks the model to load (a no-op once it already has, so a pop-back never
    /// re-triggers the AI), then advances if it succeeded.
    @MainActor
    private func load() async {
        await model.loadSuggestionsIfNeeded()
        if model.phase == .loaded {
            onLoaded()
        }
    }
}

#Preview {
    @Previewable @State var showSheet = true
    @Previewable @State var model: TrackerCreationModel = {
        let model = TrackerCreationModel(
            generate: { try await GoalAiCompletion().generateFake(for: $0) }
        )
        model.name = "Drink more water"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerGoalLoadingView(model: model) {}
        }
    }
    .presentationDetents([.large])
}
