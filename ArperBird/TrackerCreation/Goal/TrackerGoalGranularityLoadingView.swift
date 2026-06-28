//
//  TrackerGoalGranularityLoadingView.swift
//  ArperBird
//
//  Created by Olivier Picard on 28/06/2026.
//

import SwiftUI

/// The step shown on the `goal` path only when the chosen unit is the user's own
/// (no AI-anchored step). It hands the tracker name + custom unit to
/// `GranularityAiCompletion` (via the shared `TrackerCreationModel`), which
/// proposes a step natural to that unit, then advances to the reveal. Unlike the
/// other goal loaders it has no retry state: a step is non-essential — a failed
/// fetch falls through to the neutral default of `1`, which the user can still
/// dial on the reveal's Step chip. Mirrors `TrackerGoalLoadingView`.
struct TrackerGoalGranularityLoadingView: View {
    /// The flow's shared state. The view asks it to load the granularity for the
    /// currently selected (custom) unit, then hands off.
    let model: TrackerCreationModel
    /// Called once the fetch completes — success or failure alike. The enclosing
    /// `TrackerCreationFlow` swaps this transient screen out of the nav path so
    /// "back" from the reveal returns to the value page, not this spinner.
    var onLoaded: () -> Void

    var body: some View {
        VStack {
            Spacer()
            ProgressView("Setting up your tracker…")
            Spacer()
        }
        .task { await load() }
        .trackScreen("ManualTrackerCreationGoalGranularityLoading")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Setting things up")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Asks the model to load the step for the selected unit (a no-op once it
    /// already has, so a pop-back never re-triggers the AI), then advances
    /// regardless of the outcome — the step is non-essential.
    @MainActor
    private func load() async {
        await model.loadGoalGranularityIfNeeded(for: model.selectedUnit)
        onLoaded()
    }
}

#Preview {
    @Previewable @State var showSheet = true
    @Previewable @State var model: TrackerCreationModel = {
        let model = TrackerCreationModel(
            generateGranularity: {
                try await GranularityAiCompletion().generateFake(for: $0)
            }
        )
        model.name = "Read more"
        model.selectedUnit = "chapters"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerGoalGranularityLoadingView(model: model) {}
        }
    }
    .presentationDetents([.large])
}
