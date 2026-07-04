//
//  TrackerCreationFlow.swift
//  ArperBird
//
//  Created by Olivier Picard on 22/06/2026.
//

import SwiftData
import SwiftUI

enum TrackerCreationStep: Hashable {
    /// Transient spinner on the number ("Other") path: fetches the unit
    /// suggestions + behavior + emoji, then hands straight off to the reveal —
    /// the unit, max, and behavior are all editable there via the recap chips,
    /// so the number path needs nothing else from the user.
    case numberLoading
    case categoryLoading
    case categoryLabels
    /// Transient spinner shown only when the user edits the AI's suggested labels:
    /// re-derives the single/multiple flag before the reveal. See
    /// `TrackerCreationModel.reclassifyChoice(for:)`.
    case categoryReclassify
    case name
    /// Transient spinner on the goal path: fetches the unit suggestions (each
    /// with a daily target + step) plus a shared emoji, seeds the first, then
    /// hands off to the unit list. Mirrors `.numberLoading`.
    case goalLoading
    case goalUnit
    case goalValue
    /// Transient spinner on the goal path, shown only when the chosen unit is the
    /// user's own (no AI-anchored step): fetches a granularity tuned to that unit
    /// + name, then hands off to the reveal. A failed fetch falls through to the
    /// default step of 1. Swapped out of the path so "back" returns to the value
    /// page, not the spinner.
    case goalGranularityLoading
    case durationLoading
    case durationConfig
    /// Transient spinner on the binary path: fetches the emoji, then hands
    /// straight off to the reveal — binary needs nothing else from the user.
    case binaryLoading
    /// Transient spinner on the date path: fetches the emoji, then hands straight
    /// off to the reveal — a date tracker needs nothing else from the user.
    case dateLoading
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

    /// A seed skips the type and name steps: the suggestion's kind and localized
    /// name land in the model up front, and the path opens directly on the kind's
    /// loading step. `.name` stays underneath it so "back" from the reveal walks
    /// through the usual naming (pre-filled) and type screens.
    init(seed: TrackerSuggestion? = nil) {
        guard let seed else { return }
        let model = TrackerCreationModel()
        model.kind = seed.kind
        model.name = seed.localizedName
        model.aiHint = seed.hint
        _model = State(initialValue: model)
        _path = State(initialValue: [.name, Self.firstStep(for: seed.kind)])
    }

    /// The step each kind branches into after naming — shared by the name step's
    /// "Next" and the seeded entry path.
    private static func firstStep(for kind: TrackerKind) -> TrackerCreationStep {
        switch kind {
        case .goal: .goalLoading
        case .duration: .durationLoading
        case .choices: .categoryLoading
        case .binary: .binaryLoading
        case .date: .dateLoading
        case .number: .numberLoading
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            TrackerTypeView(
                onNext: { selectedKind in
                    model.kind = selectedKind
                    // Every kind names first — the name is what each path's
                    // AI-driven steps key off of, the number ("Other") path
                    // included.
                    path.append(.name)
                },
                onSuggestion: { suggestion in
                    // A chip is a pre-named pick: seed the model and jump past
                    // naming into the kind's loading step, exactly like the
                    // seeded `init` — `.name` stays underneath so "back" walks
                    // through the pre-filled naming screen.
                    model.kind = suggestion.kind
                    model.name = suggestion.localizedName
                    model.aiHint = suggestion.hint
                    path = [.name, Self.firstStep(for: suggestion.kind)]
                }
            )
            .navigationDestination(
                for: TrackerCreationStep.self,
                destination: destination
            )
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
        case .numberLoading:
            TrackerNumberLoadingView(model: model) {
                // Swap this transient spinner out of the path for the reveal, so
                // tapping "back" from the reveal returns to naming rather than
                // re-showing the loading screen. The AI-seeded unit, max, and
                // behavior are all editable on the reveal's recap chips, so the
                // number path needs no further input. Mirrors `.binaryLoading`.
                if let top = path.indices.last {
                    path[top] = .done
                }
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
                load: {
                    await model.reclassifyChoice(for: model.categoryLabels)
                }
            ) {
                // Swap this transient spinner out of the path for the reveal, so
                // tapping "back" from the reveal returns to the labels screen
                // rather than re-showing the spinner. Mirrors `.categoryLoading`.
                if let top = path.indices.last {
                    path[top] = .done
                }
            }
        case .name:
            // Seeding the field from the model keeps the typed (or seeded) name
            // visible when the step is re-shown after a pop.
            TrackerNameView(initialName: model.name, onNext: { enteredName in
                model.name = enteredName
                if let kind = model.kind {
                    path.append(Self.firstStep(for: kind))
                }
            })
        case .goalLoading:
            TrackerGoalLoadingView(model: model) {
                // Swap this transient spinner out of the path for the unit list,
                // so tapping "back" from the unit list returns to naming rather
                // than re-showing the loading screen. Mirrors `.numberLoading`.
                if let top = path.indices.last {
                    path[top] = .goalUnit
                }
            }
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
                // A unit the AI didn't propose has no sensible step or seed value,
                // so the value page drops the steppers and goes keyboard-only.
                isCustomUnit: !model.suggestions.contains {
                    $0.unit == model.selectedUnit
                },
                color: color
            ) { value in
                model.goalValue = value
                // A custom unit has no AI-anchored step, so fetch one tuned to the
                // unit before the reveal; AI units already carry the neutral default.
                path.append(model.isGoalUnitCustom ? .goalGranularityLoading : .done)
            }
        case .goalGranularityLoading:
            TrackerGoalGranularityLoadingView(model: model) {
                // Swap this transient spinner out of the path for the reveal, so
                // tapping "back" from the reveal returns to the value page rather
                // than re-showing the loading screen. Mirrors `.goalLoading`.
                if let top = path.indices.last {
                    path[top] = .done
                }
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
        case .dateLoading:
            TrackerDateLoadingView(model: model) {
                // Swap this transient spinner out of the path for the reveal, so
                // tapping "back" from the reveal returns to naming rather than
                // re-showing the loading screen. Mirrors `.binaryLoading`.
                if let top = path.indices.last {
                    path[top] = .done
                }
            }
        case .done:
            // Built through a dedicated view, not inline here: the chips edit the
            // model in place (max, choice), and only a real `body` that *reads*
            // the model re-renders on those writes. Deriving the reveal inside
            // `destination(for:)` instead would leave the pushed card stale.
            DoneRevealStep(
                model: model,
                metric: { doneMetric() },
                color: color,
                onDone: complete
            )
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
    ///
    /// The date and binary paths are the exception: their calendars have no value
    /// to fake, so a row of invented past entries would read as days the user never
    /// logged. Instead each is seeded with a single *real* point — today — so the
    /// reveal shows dashed empty slots leading into one filled "today" cell, exactly
    /// where the user's first entry will land. Honest, and it previews the affordance.
    private func doneMetric() -> Metric {
        let schema = doneSchema()
        let data: [DataPoint]
        switch model.kind {
        case .date:
            data = [.datetime(.now)]
        case .binary:
            data = [.binary(.now, true)]
        case .duration, .number where model.behavior == .cumulative:
            // Both reveal as a bar chart, which drops older values to fit the
            // card width — seed enough days to fill it. Days passed explicitly so
            // this stays put if `fakeData`'s default changes.
            data = Metric.fakeData(for: schema.config, days: 40)
        case .number:
            // The snapshot number reveals as a line chart, which also drops
            // older points to fit — seed more days than the default so it reads
            // as a real trend. Days passed explicitly so this stays put if
            // `fakeData`'s default changes.
            data = Metric.fakeData(for: schema.config, days: 22)
        default:
            data = Metric.fakeData(for: schema.config)
        }
        return Metric(from: schema, color: color, data: data)
    }

    /// The structured tracker the finished flow describes — the single source
    /// both the reveal card and the persisted metric are built from, so what the
    /// user sees in the celebration is exactly what lands on the dashboard.
    private func doneSchema() -> MetricSchema {
        // Unreachable: kind is set on the type-picker before any step that can
        // reach the reveal. Bail to a harmless default rather than crash.
        guard let kind = model.kind else {
            dismiss()
            return MetricSchema.Fake.number(title: model.name)
        }
        
        switch kind {
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
        case .date:
            // A date tracker rendered as the calendar, matching the type-picker
            // carousel.
            return MetricSchema.Fake.datetime(
                title: model.name,
                emoji: model.dateEmoji,
                chart: .calendar
            )
        case .number:
            // The open-ended "Other" path: a goal-less number whose chart follows
            // the behavior — cumulative totals stack as bars, snapshot readings
            // trace a line. min is 0; the aggregation follows suit too (cumulative
            // sums, snapshot keeps the latest reading).
            let behavior = model.behavior ?? .snapshot
            return MetricSchema.Fake.number(
                title: model.name,
                emoji: model.numberEmoji,
                unit: model.numberUnit.isEmpty ? nil : model.numberUnit,
                min: 0,
                max: model.numberMax,
                granularity: model.numberGranularity,
                goal: nil,
                behavior: behavior,
                chart: behavior == .cumulative ? .bar : .line,
                method: behavior == .cumulative
                    ? .numerical(.sum) : .numerical(.latest)
            )
        case .goal:
            // The goal path: a daily-gauge number whose sample always lands
            // above zero (min is a fifth of the goal) so the gauge reads as a
            // partial fill rather than collapsing to a line chart.
            return MetricSchema.Fake.number(
                title: model.name,
                emoji: model.goalEmoji,
                unit: model.selectedUnit,
                min: 0,
                max: model.goalValue,
                granularity: model.goalGranularity,
                goal: model.goalValue,
                chart: .dailyGauge
            )
        }
    }

}

/// Hosts the closing reveal as its own view so the model reads that drive it are
/// tracked by a real SwiftUI `body`. The chips mutate the model in place — the
/// max from its editor sheet, the choice flag from its toggle — and it's this
/// body re-evaluating that re-derives the card and the per-path recap from the
/// new state. This is the single place that knows the tracker-creation behaviour:
/// it picks the right dumb recap view for `model.kind` and injects the closures
/// that write back to the model.
private struct DoneRevealStep: View {
    let model: TrackerCreationModel
    let metric: () -> Metric
    let color: Color
    let onDone: () -> Void

    var body: some View {
        TrackerDoneView(metric: metric(), color: color, onDone: onDone) {
            recap
        }
    }

    /// The path's recap line and chips, picked from `model.kind`. Each branch is a
    /// dumb view handed typed state plus the closures that mutate the model — the
    /// behaviour lives here, never in the recap views.
    @ViewBuilder
    private var recap: some View {
        switch model.kind {
        case .number:
            DoneNumberRecap(
                maxValue: model.numberMax,
                granularity: model.numberGranularity,
                isBounded: model.numberIsBounded,
                behavior: model.behavior ?? .snapshot,
                unit: model.numberUnit.isEmpty ? nil : model.numberUnit,
                // Only the AI's proposed units, each with its default max — the
                // chip's menu offers no custom entry, so re-anchoring always lands
                // on a known max/granularity.
                units: model.numberSuggestions.compactMap { suggestion in
                    suggestion.unit.map {
                        .init(
                            name: $0,
                            defaultMax: suggestion.typicalMax,
                            defaultGranularity: suggestion.granularity
                        )
                    }
                },
                color: color,
                onEditMax: { model.setNumberMax($0) },
                onEditGranularity: { model.numberGranularity = $0 },
                onToggleBehavior: {
                    // Flip cumulative ↔ snapshot in place; defaulting an unset
                    // behavior to snapshot mirrors how the reveal derives it.
                    model.behavior =
                        (model.behavior ?? .snapshot) == .cumulative
                        ? .snapshot : .cumulative
                },
                onSelectUnit: { model.chooseNumberUnit($0) }
            )
        case .choices:
            DoneCategoryRecap(
                allowsMultiple: model.categoryAllowsMultiple,
                count: model.categoryLabels.count,
                color: color,
                onToggleChoice: { model.categoryAllowsMultiple.toggle() }
            )
        case .binary:
            DoneBinaryRecap()
        case .date:
            DoneDateRecap()
        case .duration:
            DoneDurationRecap(
                maxSeconds: model.durationMaxSeconds,
                color: color,
                onUpdate: { model.setDurationMax($0) }
            )
        case .goal:
            DoneGoalRecap(
                goalValue: model.goalValue,
                granularity: model.goalGranularity,
                unit: model.selectedUnit,
                units: model.suggestions.map(\.unit),
                // The user's own unit, kept in the menu so they can switch back to
                // it (and its target) after trying an AI one.
                customUnit: model.goalMenuCustomUnit,
                color: color,
                onSelectUnit: { model.selectGoalUnit($0) },
                onEditGoal: { model.goalValue = max(0, $0) },
                onEditGranularity: { model.goalGranularity = $0 }
            )
        case nil:
            EmptyView()  // unreachable: kind is set before any later step.
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
