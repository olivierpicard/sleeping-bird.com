//
//  TrackerCategoryLoadingView.swift
//  ArperBird
//
//  Created by Olivier Picard on 25/06/2026.
//

import SwiftUI

/// The step that follows naming on the `choices` path. It hands the tracker name
/// to `CategoryAiCompletion` (via the shared `TrackerCreationModel`), which fills
/// in the suggested labels, the single/multiple flag, and a matching emoji, then
/// advances to the editable labels screen. The model memoizes the fetch, so
/// reappearing after a pop reuses the result instead of re-triggering the AI.
struct TrackerCategoryLoadingView: View {
    /// The flow's shared state. The view reads `categoryPhase` to decide between
    /// the spinner, the retry state, and advancing.
    let model: TrackerCreationModel
    /// The async work to run while the spinner shows. Defaults to the initial
    /// suggestion fetch; the flow swaps in the single/multiple re-classification
    /// when the user edited the AI's labels — both report through `categoryPhase`.
    var load: () async -> Void
    /// Called once the work has loaded. The enclosing `TrackerCreationFlow` swaps
    /// this transient screen out of the nav path so "back" from the next screen
    /// returns to naming, not to this spinner.
    var onLoaded: () -> Void

    init(
        model: TrackerCreationModel,
        load: (() async -> Void)? = nil,
        onLoaded: @escaping () -> Void = {}
    ) {
        self.model = model
        // Default can't reference `model`, so coalesce here.
        self.load = load ?? { await model.loadCategoryIfNeeded() }
        self.onLoaded = onLoaded
    }

    var body: some View {
        VStack {
            Spacer()
            switch model.categoryPhase {
            case .failed:
                ContentUnavailableView {
                    Label("Couldn't set up your tracker", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(action: { Task { await run() } }) {
                        Text("Try again")
                    }
                }
            default:
                ProgressView("Setting up your tracker…")
                    .tint(nil)
            }
            Spacer()
        }
        .task { await run() }
        .trackScreen("ManualTrackerCreationCategoryLoading")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Setting things up")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Runs the injected work (the initial fetch is a no-op once it already
    /// loaded, so a pop-back never re-triggers it), then advances if it
    /// succeeded — both kinds of work report through `categoryPhase`.
    @MainActor
    private func run() async {
        await load()
        if model.categoryPhase == .loaded {
            onLoaded()
        }
    }
}

#Preview {
    @Previewable @State var showSheet = true
    @Previewable @State var model: TrackerCreationModel = {
        let model = TrackerCreationModel(
            generateCategory: { try await CategoryAiCompletion().generateFake(for: $0) }
        )
        model.name = "Mood"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerCategoryLoadingView(model: model, onLoaded: {})
        }
    }
    .presentationDetents([.large])
}

#Preview("Failure") {
    @Previewable @State var showSheet = true
    @Previewable @State var model: TrackerCreationModel = {
        let model = TrackerCreationModel(
            generateCategory: { _ in throw URLError(.notConnectedToInternet) }
        )
        model.name = "Mood"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerCategoryLoadingView(model: model, onLoaded: {})
        }
    }
    .presentationDetents([.large])
}
