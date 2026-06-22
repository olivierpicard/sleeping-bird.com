//
//  TrackerCreationFlow.swift
//  ArperBird
//
//  Created by Olivier Picard on 22/06/2026.
//

import SwiftUI

enum TrackerCreationStep: Hashable {
    case numberType
    case categoryLabels
    case name
}

/// Coordinates the manual tracker-creation steps in a single push-based
/// `NavigationStack`, mirroring the flexible pattern of `OnboardingFlow`. Each
/// step view takes an `onNext` closure rather than owning its own navigation.
struct TrackerCreationFlow: View {
    var onComplete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var path: [TrackerCreationStep] = []
    @State private var kind: TrackerKind?
    @State private var behavior: MetricBehavior?
    @State private var categoryLabels: [String] = []

    /// The step that follows type selection. The open-ended "Other" number kind
    /// needs an extra step to disambiguate cumulative vs snapshot behavior, and
    /// `choices` needs the user to author their category labels; every other kind
    /// (goal included) jumps straight to naming.
    private func step(after kind: TrackerKind) -> TrackerCreationStep {
        switch kind {
        case .number: .numberType
        case .choices: .categoryLabels
        default: .name
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            TrackerTypeView { selectedKind in
                kind = selectedKind
                path.append(step(after: selectedKind))
            }
            .navigationDestination(for: TrackerCreationStep.self) { step in
                switch step {
                case .numberType:
                    TrackerNumberTypeView { selectedBehavior in
                        behavior = selectedBehavior
                        path.append(.name)
                    }
                case .categoryLabels:
                    TrackerCategoryLabelsView { labels in
                        categoryLabels = labels
                        path.append(.name)
                    }
                case .name:
                    TrackerNameView(onNext: { _ in onComplete() })
                }
            }

        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        TrackerCreationFlow()
    }
    .presentationDetents([.large])
}
