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
    case goalSuggestions
    case goalUnit
    case goalValue
    case goalDone
}

/// Coordinates the manual tracker-creation steps in a single push-based
/// `NavigationStack`, mirroring the flexible pattern of `OnboardingFlow`. Each
/// step view takes an `onNext` closure rather than owning its own navigation.
struct TrackerCreationFlow: View {
    var onComplete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var path: [TrackerCreationStep] = []

    /// The single source of truth for the whole flow. Owning the state here —
    /// rather than in per-step `@State` and `NavigationPath` payloads — is what
    /// lets data survive back-navigation; see `TrackerCreationModel`.
    @State private var model = TrackerCreationModel()

    /// The goal path has no color-picker step yet, so previews and the assembled
    /// gauge card share the app accent.
    private let color: Color = .accent

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
                model.kind = selectedKind
                path.append(step(after: selectedKind))
            }
            .navigationDestination(for: TrackerCreationStep.self, destination: destination)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
            }
        }
    }

    /// Builds each pushed step. Every destination reads from / writes to `model`,
    /// so the path entries stay payload-free and the data survives a pop.
    @ViewBuilder
    private func destination(for step: TrackerCreationStep) -> some View {
        switch step {
        case .numberType:
            TrackerNumberTypeView { selectedBehavior in
                model.behavior = selectedBehavior
                path.append(.name)
            }
        case .categoryLabels:
            TrackerCategoryLabelsView { labels in
                model.categoryLabels = labels
                path.append(.name)
            }
        case .name:
            TrackerNameView(onNext: { enteredName in
                model.name = enteredName
                // The goal path branches into AI-suggested configurations; every
                // other kind is fully specified by now.
                if model.kind == .goal {
                    path.append(.goalSuggestions)
                } else {
                    onComplete()
                }
            })
        case .goalSuggestions:
            TrackerGoalSuggestionsView(
                model: model,
                color: color,
                onNext: { schema in
                    // Card accepted as-is: skip the edit pages and jump straight
                    // to the reveal.
                    model.select(schema)
                    path.append(.goalDone)
                },
                onEdit: { schema in
                    model.select(schema)
                    path.append(.goalUnit)
                }
            )
        case .goalUnit:
            TrackerGoalUnitListView(
                name: model.name,
                options: model.suggestions.map {
                    .init(unit: $0.unit, dailyGoal: $0.dailyGoal)
                },
                selectedUnit: model.selectedUnit,
                color: color
            ) { unit in
                model.chooseUnit(unit)
                path.append(.goalValue)
            }
        case .goalValue:
            TrackerGoalValueView(
                name: model.name,
                unit: model.selectedUnit,
                suggestedGoal: model.goalValue,
                color: color
            ) { value in
                model.goalValue = value
                path.append(.goalDone)
            }
        case .goalDone:
            TrackerGoalDoneView(
                name: model.name,
                emoji: model.goalEmoji,
                unit: model.selectedUnit,
                goal: model.goalValue,
                color: color
            ) {
                onComplete()
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

