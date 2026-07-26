//
//  TrackerNumberLoadingView.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/06/2026.
//

import SwiftUI

/// The step that follows naming on the `number` ("Other") path. It hands the
/// tracker name to `NumberAiCompletion` (via the shared `TrackerCreationModel`),
/// which proposes a few units — each with a realistic max and natural
/// granularity — plus a shared behavior guess, then advances to the unit list.
/// The model memoizes the fetch, so reappearing after a pop reuses the result
/// instead of re-triggering the AI. Mirrors `TrackerDurationLoadingView`.
struct TrackerNumberLoadingView: View {
    /// The flow's shared state. The view asks it to load and reads `numberPhase`
    /// to decide between the spinner, the retry state, and advancing.
    let model: TrackerCreationModel
    /// Called once the number suggestions have loaded. The enclosing
    /// `TrackerCreationFlow` swaps this transient screen out of the nav path so
    /// "back" from the unit list returns to naming, not to this spinner.
    var onLoaded: () -> Void

    var body: some View {
        VStack {
            Spacer()
            switch model.numberPhase {
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
        .trackScreen("ManualTrackerCreationNumberLoading")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Setting things up")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Asks the model to load (a no-op once it already has, so a pop-back never
    /// re-triggers the AI), then advances if it succeeded.
    @MainActor
    private func load() async {
        await model.loadNumberIfNeeded()
        if model.numberPhase == .loaded {
            onLoaded()
        }
    }
}

#Preview {
    @Previewable @State var showSheet = true
    @Previewable @State var model: TrackerCreationModel = {
        let model = TrackerCreationModel(
            generateNumber: { try await NumberAiCompletion().generateFake(for: $0) }
        )
        model.name = "Body weight"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerNumberLoadingView(model: model) {}
        }
    }
    .presentationDetents([.large])
}

#Preview("Failure") {
    @Previewable @State var showSheet = true
    @Previewable @State var model: TrackerCreationModel = {
        let model = TrackerCreationModel(
            generateNumber: { _ in throw URLError(.notConnectedToInternet) }
        )
        model.name = "Body weight"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerNumberLoadingView(model: model) {}
        }
    }
    .presentationDetents([.large])
}
