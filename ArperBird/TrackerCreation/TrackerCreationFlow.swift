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
    case categoryLoading
    case categoryLabels
    /// Transient spinner shown only when the user edits the AI's suggested labels:
    /// re-derives the single/multiple flag before the reveal. See
    /// `TrackerCreationModel.reclassifyChoice(for:)`.
    case categoryReclassify
    case name
    case goalSuggestions
    case goalUnit
    case goalValue
    case durationLoading
    case durationConfig
    /// Transient spinner on the binary path: fetches the emoji, then hands
    /// straight off to the reveal — binary needs nothing else from the user.
    case binaryLoading
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
    /// needs an extra step to disambiguate cumulative vs snapshot behavior; every
    /// other kind (goal, duration, and choices included) jumps straight to naming
    /// — the name is what their AI-driven steps key off of.
    private func step(after kind: TrackerKind) -> TrackerCreationStep {
        switch kind {
        case .number: .numberType
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
        case .categoryLoading:
            TrackerCategoryLoadingView(model: model) {
                // Swap this transient spinner out of the path for the labels
                // screen, so tapping "back" from the labels returns to naming
                // rather than re-showing the loading screen. Mutating the top
                // entry in place animates as a normal push.
                if let top = path.indices.last {
                    path[top] = .categoryLabels
                }
            }
        case .categoryLabels:
            TrackerCategoryLabelsView(
                color: color,
                initialLabels: model.categoryLabels
            ) { labels in
                // Trust the AI's single/multiple guess unless the user replaced or
                // deleted one of its labels — that edit is the signal the name-only
                // guess misread the metric, so re-derive the flag from the real
                // labels. Additions alone keep the AI's guess.
                let edited = model.shouldReclassifyChoice(for: labels)
                model.categoryLabels = labels
                path.append(edited ? .categoryReclassify : .done)
            }
        case .categoryReclassify:
            TrackerCategoryLoadingView(
                model: model,
                load: { await model.reclassifyChoice(for: model.categoryLabels) }
            ) {
                // Swap this transient spinner out of the path for the reveal, so
                // tapping "back" from the reveal returns to the labels screen
                // rather than re-showing the spinner. Mirrors `.categoryLoading`.
                if let top = path.indices.last {
                    path[top] = .done
                }
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
                case .choices:
                    path.append(.categoryLoading)
                case .binary:
                    path.append(.binaryLoading)
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
        case .binaryLoading:
            TrackerBinaryLoadingView(model: model) {
                // Swap this transient spinner out of the path for the reveal, so
                // tapping "back" from the reveal returns to naming rather than
                // re-showing the loading screen. Mirrors `.durationLoading`.
                if let top = path.indices.last {
                    path[top] = .done
                }
            }
        case .done:
            TrackerDoneView(
                metric: doneMetric(),
                color: color,
                recap: doneRecap(),
                categoryChoice: doneCategoryChoice(),
                // Tapping the reveal's choice chip flips single ↔ multiple right
                // there: writing `categoryAllowsMultiple` re-derives the recap and
                // the card's chart (pie ↔ bar) in place.
                onToggleChoice: { model.categoryAllowsMultiple.toggle() }
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
        case .choices:
            // Single choice reads best as a pie (composition of one pick per
            // entry); multiple choice as a bar (independent counts per label) —
            // matching the type-picker carousel.
            return model.categoryAllowsMultiple
                ? MetricSchema.Fake.categoryMultiple(
                    title: model.name,
                    emoji: model.categoryEmoji,
                    labels: model.categoryLabels,
                    chart: .bar
                )
                : MetricSchema.Fake.categorySingle(
                    title: model.name,
                    emoji: model.categoryEmoji,
                    labels: model.categoryLabels,
                    chart: .pie
                )
        case .binary:
            // A yes/no tracker rendered as the binary calendar, matching the
            // type-picker carousel.
            return MetricSchema.Fake.binary(
                title: model.name,
                emoji: model.binaryEmoji,
                chart: .calendar
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

    /// The selection mode surfaced by the reveal's choice chip — only on the
    /// choices path, where flipping single ↔ multiple is meaningful. Nil
    /// everywhere else, which hides the chip.
    private func doneCategoryChoice() -> TrackerDoneView.CategoryChoice? {
        guard model.kind == .choices else { return nil }
        return model.categoryAllowsMultiple ? .multiple : .single
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
        case .choices:
            return model.categoryAllowsMultiple
                ? "Pick several from \(model.categoryLabels.count) categories"
                : "Pick one of \(model.categoryLabels.count) categories"
        case .binary:
            return "Track yes or no each day"
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
