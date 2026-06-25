//
//  TrackerCreationFlow.swift
//  ArperBird
//
//  Created by Olivier Picard on 22/06/2026.
//

import SwiftData
import SwiftUI

enum TrackerCreationStep: Hashable {
    case numberType
    case categoryLabels
    case name
    case goalSuggestions
    case goalUnit
    case goalValue
    case durationLoading
    case durationConfig
    /// The shared celebration reveal that closes every path: the assembled card
    /// drops in under a "you're all set" headline. The destination builds the
    /// right `Metric` from `model.kind`, so a single step serves all types.
    case done
}

/// Coordinates the manual tracker-creation steps in a single push-based
/// `NavigationStack`, mirroring the flexible pattern of `OnboardingFlow`. Each
/// step view takes an `onNext` closure rather than owning its own navigation.
struct TrackerCreationFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
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
                // The goal and duration paths branch into AI-driven steps; the
                // remaining kinds aren't wired up to the reveal yet.
                switch model.kind {
                case .goal:
                    path.append(.goalSuggestions)
                case .duration:
                    path.append(.durationLoading)
                default:
                    break
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
                    path.append(.done)
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
                path.append(.done)
            }
        case .durationLoading:
            TrackerDurationLoadingView(model: model) {
                // Swap this transient spinner out of the path for the result, so
                // tapping "back" from the result returns to naming rather than
                // re-showing the loading screen. Mutating the top entry in place
                // animates as a normal push.
                if let top = path.indices.last {
                    path[top] = .durationConfig
                }
            }
        case .durationConfig:
            TrackerDurationConfigView(
                name: model.name,
                suggestedMaxSeconds: model.durationMaxSeconds,
                color: color
            ) { seconds in
                model.setDurationMax(seconds)
                path.append(.done)
            }
        case .done:
            TrackerDoneView(
                metric: doneMetric(),
                color: color,
                recap: doneRecap()
            ) {
                complete()
            }
        }
    }

    // MARK: - Persistence

    /// Closes the flow once the user accepts the finished tracker on the reveal:
    /// persist it, then dismiss ourselves — the same `@Environment(\.dismiss)` the
    /// cancel button uses, so the flow has a single exit path.
    private func complete() {
        persistMetric()
        dismiss()
    }

    /// Inserts the finished tracker into the store. Mirrors `MetricGenerator`'s
    /// insert-and-let-autosave-persist path, but the card that actually lands on
    /// the dashboard starts *empty* — the sample data in `doneMetric()` exists
    /// only to make the reveal chart look alive.
    private func persistMetric() {
        context.insert(Metric(from: doneSchema(), color: color))
    }

    // MARK: - Reveal card

    /// Assembles the card shown on the closing `.done` screen from the finished
    /// flow state. It's seeded with sample data (`Metric.fakeData`) so the chart
    /// looks alive in the reveal — mirroring the type-picker carousel — even
    /// though the metric that lands on the dashboard (see `persistMetric`) starts
    /// empty.
    private func doneMetric() -> Metric {
        let schema = doneSchema()
        return Metric(
            from: schema,
            color: color,
            data: Metric.fakeData(for: schema.config)
        )
    }

    /// The structured tracker the finished flow describes — the single source
    /// both the reveal card and the persisted metric are built from, so what the
    /// user sees in the celebration is exactly what lands on the dashboard.
    private func doneSchema() -> MetricSchema {
        switch model.kind {
        case .duration:
            return MetricSchema.Fake.duration(
                title: model.name,
                emoji: model.durationEmoji,
                // No sub-minute granularity on the wheel, so format the sample in
                // hours once the bound clears an hour, minutes otherwise.
                granularity: model.durationMaxSeconds >= 3600 ? "h" : "m",
                maxInSeconds: max(1, model.durationMaxSeconds),
                chart: .bar
            )
        default:
            // The goal path: a daily-gauge number whose sample always lands
            // above zero (min is a fifth of the goal) so the gauge reads as a
            // partial fill rather than collapsing to a line chart.
            return MetricSchema.Fake.number(
                title: model.name,
                emoji: model.goalEmoji,
                unit: model.selectedUnit,
                min: model.goalValue * 0.2,
                max: model.goalValue,
                granularity: 1,
                goal: model.goalValue,
                chart: .dailyGauge
            )
        }
    }

    /// The one-line recap under the reveal card, tailored to the path.
    private func doneRecap() -> LocalizedStringKey? {
        switch model.kind {
        case .duration:
            let seconds = max(0, model.durationMaxSeconds)
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            let text =
                hours > 0
                ? (minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h")
                : "\(minutes)m"
            return "Tracks up to \(text)"
        default:
            return "Goal: \(model.goalValue.formatted(.number)) \(model.selectedUnit) per day"
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
    .modelContainer(for: Metric.self, inMemory: true)
}

