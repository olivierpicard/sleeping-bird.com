//
//  TrackerCreationFlow.swift
//  ArperBird
//
//  Created by Olivier Picard on 22/06/2026.
//

import PostHog
import SwiftData
import SwiftUI

enum TrackerCreationStep: Hashable {
    /// Asks *how* to log an already-resolved intent — the entry point for a
    /// seeded (dashboard badge) creation, in place of `TrackerIntentView`.
    /// Only ever the first entry in `path`; see `TrackerCreationFlow.init`.
    case formatPicker
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
    @Environment(Store.self) private var store
    @State private var path: [TrackerCreationStep] = []
    /// Shown in place of persisting when `complete()` finds the user not yet
    /// premium — there is no free allowance. Saving only happens once this
    /// resolves with `store.isPremium == true` — see
    /// `sheet(isPresented:onDismiss:)` below.
    @State private var showPaywall = false
    /// Set right before a completed dismiss (direct save, or a purchase from
    /// the paywall interrupt) so `onDisappear` below can tell a finished flow
    /// apart from one the user backed out of.
    @State private var didComplete = false

    /// The single source of truth for the whole flow. Owning the state here —
    /// rather than in per-step `@State` and `NavigationPath` payloads — is what
    /// lets data survive back-navigation; see `TrackerCreationModel`. The
    /// tracker's color lives on `model` (not a separate `@State` here) for the
    /// same reason — see `TrackerCreationModel.color`.
    @State private var model = TrackerCreationModel()

    /// A dashboard badge tap arrives as a `seed`: rather than skipping the intent
    /// screen, it's handed to `TrackerIntentView` as a pre-resolved selection, so
    /// the flow opens on the same intent screen the "+" button reaches — just with
    /// the card already showing. The user still taps "Continue", which routes
    /// through the shared `onContinue` seeding path like a typed prompt.
    private let seed: TrackerSuggestion?

    /// When true, the root intent screen raises the keyboard and focuses its
    /// field on appear — passed for the from-scratch (`seed == nil`) route so a
    /// tap on the empty-dashboard field CTA lands straight in typing. A seeded
    /// entry arrives pre-resolved, so it opts out.
    private let autofocus: Bool

    init(
        seed: TrackerSuggestion? = nil,
        autofocus: Bool = false,
        preloaded: TrackerCreationModel? = nil,
        preloadSucceeded: Bool = false
    ) {
        self.seed = seed
        self.autofocus = autofocus
        // A badge with a single logging format has nothing to pick on the "How
        // to track it" screen, so skip the format picker entirely: seed the
        // model from that one format up front and open straight on the kind's
        // first step, which runs its loading spinner into the reveal. With two
        // or more formats the picker still leads (see `.formatPicker`).
        if let seed, seed.formats.count == 1 {
            let kind = seed.formats[0].kind
            // The empty dashboard may have already run this single-format seed's
            // first AI load during its "preparing" glow (see `preloadSeed`). When
            // it did — and it succeeded — reuse that warmed model and open past
            // the now-redundant loading spinner on the kind's post-load step, so
            // the glow and the load are the *same* beat rather than two spinners
            // back to back. Otherwise fall back to a fresh model on the loading
            // step, which runs the load itself (and shows retry on failure).
            let model = preloaded ?? {
                let model = TrackerCreationModel()
                model.kind = kind
                model.name = seed.localizedTrackerName
                model.aiHint = seed.localizedTrackerName
                return model
            }()
            model.color = kind.previewColor
            _model = State(initialValue: model)
            _path = State(initialValue: [
                preloaded != nil && preloadSucceeded
                    ? Self.postLoadStep(for: kind)
                    : Self.firstStep(for: kind)
            ])
        } else {
            // A badge tap already resolved the intent, so open straight on the
            // format picker instead of `TrackerIntentView`. It stays pushed on
            // top of that root screen (rather than replacing it), so a swipe
            // back still lands on the pre-filled intent screen as a fallback.
            _path = State(initialValue: seed != nil ? [.formatPicker] : [])
        }
    }

    /// Whether `step` is the screen the user first landed on — the entry point
    /// that shows a close (X) instead of a back arrow. Only true for a *seeded*
    /// flow, where the intent root is an unseen fallback and `path[0]` is the real
    /// entry; an unseeded flow enters on the intent root, so every `path` entry is
    /// a push. Comparing against `path.first` (the live value, post loading-swap)
    /// keeps this correct across the in-place spinner swaps — no two distinct
    /// steps share a value, so the match is unambiguous.
    private func isEntry(_ step: TrackerCreationStep) -> Bool {
        seed != nil && path.first == step
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

    /// The step a *preloaded* single-format seed opens on — the one the kind's
    /// loading step would have advanced to once its AI load finished. For the
    /// paths that go straight to the reveal (number/binary/date/duration) that's
    /// `.done`; the choices and goal paths land on their interactive follow-up
    /// (labels / unit list) instead. Only used when the load already succeeded
    /// during the empty-dashboard glow; see `init`.
    private static func postLoadStep(for kind: TrackerKind) -> TrackerCreationStep {
        switch kind {
        case .number, .binary, .date, .duration: .done
        case .choices: .categoryLabels
        case .goal: .goalUnit
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            TrackerIntentView(
                preselected: seed,
                autofocusField: autofocus,
                onContinue: { kind, name, intentColor in
                    // The intent screen already captured the name and picked a
                    // format (kind), so seed the model and jump straight into the
                    // kind's step machinery — no `.name` step. The typed prompt /
                    // chip name rides along as `aiHint` for the loading steps, and
                    // the per-kind preview color threads through the reveal and the
                    // persisted metric.
                    model.kind = kind
                    model.name = name
                    model.aiHint = name
                    model.color = intentColor
                    path = [Self.firstStep(for: kind)]
                }
            )
            // The intent root: an entry point whenever it's the screen the user
            // actually lands on (the "+" button, `seed == nil`). When seeded it's
            // an unseen fallback beneath the pushed entry, so the X is harmless.
            .modifier(NavChrome(isEntry: seed == nil, dismiss: dismiss))
            .navigationDestination(for: TrackerCreationStep.self) { step in
                destination(for: step)
                    // The first screen the user lands on shows a close (X); every
                    // screen pushed after it shows iOS's natural back arrow. The
                    // entry is `path[0]` only for a seeded flow (badge / empty
                    // dashboard) — an unseeded flow enters on the intent root, so
                    // its `path` entries are all pushes.
                    .modifier(NavChrome(isEntry: isEntry(step), dismiss: dismiss))
            }
        }
        // The nav-bar chrome (back chevron, close button) stays the plain
        // iOS default (black/white) rather than the tracker's color — every
        // step's own controls (chips, steppers, CTAs) still get the tracker's
        // corrected `mainColor` explicitly, so config chrome reads as
        // tracker-tinted without the nav bar itself following along.
        .sheet(isPresented: $showPaywall, onDismiss: {
            // Fires whether the sheet closed via a purchase (`PaywallView`
            // dismisses itself on success) or the user backing out. Only the
            // former leaves `isPremium` true, so this is the single gate that
            // decides whether "Add to dashboard" actually saved anything —
            // backing out of the paywall always leaves the reveal on screen
            // with nothing persisted.
            if store.isPremium {
                didComplete = true
                persistMetric()
                dismiss()
            } else {
                // The single explicit signal for a decline — otherwise it's only
                // inferable by joining `tracker_creation_paywall_shown` against
                // the absence of `tracker_created` in the same session.
                PostHogSDK.shared.capture(
                    "tracker_creation_paywall_declined",
                    properties: ["kind": model.kind?.rawValue ?? "unknown"]
                )
            }
        }) {
            PaywallView()
        }
        .onDisappear {
            guard !didComplete else { return }
            PostHogSDK.shared.capture(
                "tracker_creation_abandoned",
                properties: [
                    "last_step": path.last.map { String(describing: $0) } ?? "intent",
                    "kind": model.kind?.rawValue ?? "none",
                ]
            )
        }
    }

    /// Builds each pushed step. Every destination reads from / writes to `model`,
    /// so the path entries stay payload-free and the data survives a pop.
    @ViewBuilder
    private func destination(for step: TrackerCreationStep) -> some View {
        switch step {
        case .formatPicker:
            // Only reachable when `seed` is set — see `init`.
            if let seed {
                // The resolved suggestion's color follows its best-fit
                // (first) format, mirroring `TrackerIntentView`'s own
                // per-kind tint so a badge tap and a typed prompt land on
                // the same shade for the same idea.
                let resolvedColor = (seed.formats.first?.kind ?? seed.kind)
                    .previewColor
                TrackerFormatPickerView(
                    name: seed.localizedTrackerName,
                    emoji: seed.emoji,
                    formats: seed.formats.map {
                        .make(
                            for: $0,
                            name: seed.localizedTrackerName,
                            emoji: seed.emoji
                        )
                    },
                    color: resolvedColor,
                    onContinue: { kind in
                        // Mirrors `TrackerIntentView`'s `onContinue`: seed the
                        // model from the already-known name/color and jump
                        // straight into the chosen format's step machinery.
                        // *Append* (not replace) so the format picker stays in the
                        // stack beneath the kind's steps — that's what lets the
                        // reveal offer a back arrow returning to the picker.
                        model.kind = kind
                        model.name = seed.localizedTrackerName
                        model.aiHint = seed.localizedTrackerName
                        model.color = resolvedColor
                        path.append(Self.firstStep(for: kind))
                    }
                )
            }
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
                color: model.color,
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
            TrackerNameView(initialName: model.name, color: model.color, onNext: { enteredName in
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
                color: model.color
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
                color: model.color
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
                // Swap this transient spinner out of the path for the reveal, so
                // tapping "back" from the reveal returns to the intent screen
                // rather than re-showing the loading screen. The duration path
                // skips its config screen — the suggested max is editable on the
                // reveal's recap chip, so it needs no further input. Mirrors
                // `.binaryLoading`.
                if let top = path.indices.last {
                    path[top] = .done
                }
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
                onDone: complete
            )
        }
    }

    // MARK: - Persistence

    /// Called when the user taps "Add to dashboard" on the reveal. A
    /// non-premium user is interrupted with the paywall instead of saving
    /// straight away — `sheet(isPresented:onDismiss:)` above is what actually
    /// persists once (and only if) that resolves with the user premium, so
    /// there's no path from this button to a saved tracker that skips it.
    private func complete() {
        if store.requiresPaywall {
            PostHogSDK.shared.capture(
                "tracker_creation_paywall_shown",
                properties: ["kind": model.kind?.rawValue ?? "unknown"]
            )
            showPaywall = true
        } else {
            didComplete = true
            persistMetric()
            dismiss()
        }
    }

    /// Inserts the finished tracker into the store. Mirrors `MetricGenerator`'s
    /// insert-and-let-autosave-persist path, but the card that actually lands on
    /// the dashboard starts *empty* — the sample data in `doneMetric()` exists
    /// only to make the reveal chart look alive.
    private func persistMetric() {
        context.insert(Metric(from: doneSchema(), color: model.color))
        PostHogSDK.shared.capture(
            "tracker_created",
            properties: ["kind": model.kind?.rawValue ?? "unknown"]
        )
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
        return Metric(from: schema, color: model.color, data: data)
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

/// The per-screen leading nav chrome for the creation flow. An *entry* screen —
/// the first one the user lands on — hides the automatic back arrow and shows a
/// close (X) instead; every screen pushed after it keeps iOS's natural back
/// arrow and no X. Applied to the intent root and each pushed destination so the
/// chrome follows the actual journey rather than raw `NavigationStack` depth.
private struct NavChrome: ViewModifier {
    let isEntry: Bool
    let dismiss: DismissAction

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(isEntry)
            .toolbar {
                if isEntry {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark") 
                        }
                    }
                }
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
    @Bindable var model: TrackerCreationModel
    let metric: () -> Metric
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// The contrast-corrected variant for text-bearing chrome: the recap chips'
    /// colored text and strokes. The card itself (fill, bloom, sparkles) derives
    /// its own raw color straight from the `metric` via `TrackerDoneView`, so
    /// this view only needs the corrected shade.
    private var mainColor: Color { model.mainColor(in: colorScheme) }

    /// The reveal card, built once and memoized so editing the name or emoji
    /// doesn't reshuffle the (randomly seeded) sample chart on every keystroke.
    /// Only a chip that changes the chart's shape/scale rebuilds it — see
    /// `chartSignature`. The header's edits go to the model, not this card, so
    /// the card's own name/emoji stay unused here.
    @State private var card: Metric?

    /// Guards `tracker_default_edited` for the header fields so a rename fires
    /// once per reveal visit rather than once per keystroke — `nameField`/
    /// `emojiField` wrap direct `TextField`/emoji-keyboard bindings, which write
    /// on every character, unlike the recap chips' discrete tap actions.
    @State private var didCaptureNameEdit = false
    @State private var didCaptureEmojiEdit = false

    /// Wraps `model.name` to report the header field overriding the AI-seeded
    /// name — once per visit, and without the typed text itself (mirrors
    /// `empty_dashboard_draft_submitted` logging only a length, never the
    /// content) since a tracker name can carry sensitive personal context.
    private var nameField: Binding<String> {
        Binding(
            get: { model.name },
            set: { newValue in
                if !didCaptureNameEdit, newValue != model.name {
                    didCaptureNameEdit = true
                    PostHogSDK.shared.capture(
                        "tracker_default_edited",
                        properties: [
                            "kind": model.kind?.rawValue ?? "unknown",
                            "field": "name",
                        ]
                    )
                }
                model.name = newValue
            }
        )
    }

    /// Wraps `model.emoji` to report the header chip overriding the AI-seeded
    /// emoji — once per visit. Unlike the name, a single emoji glyph carries no
    /// sensitive content, so it's logged as the chip's `value`.
    private var emojiField: Binding<String> {
        Binding(
            get: { model.emoji },
            set: { newValue in
                if !didCaptureEmojiEdit, newValue != model.emoji {
                    didCaptureEmojiEdit = true
                    captureDefaultEdited(field: "emoji", value: newValue)
                }
                model.emoji = newValue
            }
        )
    }

    var body: some View {
        let displayed = card ?? metric()
        return TrackerDoneView(
            metric: displayed,
            name: nameField,
            emoji: emojiField,
            onDone: onDone
        ) {
            recap
        }
        .onAppear { if card == nil { card = displayed } }
        .onChange(of: chartSignature) { card = metric() }
    }

    /// The model facets the sample chart is derived from — the recap chips edit
    /// these, so a change means the card must rebuild. Name and emoji are absent
    /// on purpose: they don't touch the chart, so editing them leaves it untouched.
    private var chartSignature: String {
        [
            String(model.numberMax),
            String(model.numberGranularity),
            model.numberUnit,
            String(describing: model.behavior),
            String(model.categoryAllowsMultiple),
            String(model.categoryLabels.count),
            String(model.goalValue),
            String(model.goalGranularity),
            model.selectedUnit,
        ].joined(separator: "|")
    }

    /// Reports a recap chip overriding one of the AI's proposed defaults —
    /// `field` names which one (e.g. `"number_max"`), `value` its new setting.
    /// Captured here (not inside `TrackerCreationModel`'s mutators) because
    /// each closure below is this action's one and only call site, and already
    /// knows which field it's touching for free.
    private func captureDefaultEdited(field: String, value: Any) {
        PostHogSDK.shared.capture(
            "tracker_default_edited",
            properties: [
                "kind": model.kind?.rawValue ?? "unknown",
                "field": field,
                "value": value,
            ]
        )
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
                color: mainColor,
                onEditMax: {
                    captureDefaultEdited(field: "number_max", value: $0)
                    model.setNumberMax($0)
                },
                onEditGranularity: {
                    captureDefaultEdited(field: "number_step", value: $0)
                    model.numberGranularity = $0
                },
                onToggleBehavior: {
                    // Flip cumulative ↔ snapshot in place; defaulting an unset
                    // behavior to snapshot mirrors how the reveal derives it.
                    let next: MetricBehavior =
                        (model.behavior ?? .snapshot) == .cumulative
                        ? .snapshot : .cumulative
                    captureDefaultEdited(field: "number_behavior", value: next.rawValue)
                    model.behavior = next
                },
                onSelectUnit: {
                    captureDefaultEdited(field: "number_unit", value: $0)
                    model.chooseNumberUnit($0)
                }
            )
        case .choices:
            DoneCategoryRecap(
                allowsMultiple: model.categoryAllowsMultiple,
                count: model.categoryLabels.count,
                color: mainColor,
                onToggleChoice: {
                    model.categoryAllowsMultiple.toggle()
                    captureDefaultEdited(
                        field: "category_choice_mode",
                        value: model.categoryAllowsMultiple ? "multiple" : "single"
                    )
                }
            )
        case .binary:
            DoneBinaryRecap()
        case .date:
            DoneDateRecap()
        case .duration:
            DoneDurationRecap()
        case .goal:
            DoneGoalRecap(
                goalValue: model.goalValue,
                granularity: model.goalGranularity,
                unit: model.selectedUnit,
                units: model.suggestions.map(\.unit),
                // The user's own unit, kept in the menu so they can switch back to
                // it (and its target) after trying an AI one.
                customUnit: model.goalMenuCustomUnit,
                color: mainColor,
                onSelectUnit: {
                    captureDefaultEdited(field: "goal_unit", value: $0)
                    model.selectGoalUnit($0)
                },
                onEditGoal: {
                    let value = max(0, $0)
                    captureDefaultEdited(field: "goal_target", value: value)
                    model.goalValue = value
                },
                onEditGranularity: {
                    captureDefaultEdited(field: "goal_step", value: $0)
                    model.goalGranularity = $0
                }
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
            .environment(Store())
    }
    .presentationDetents([.large])
    .modelContainer(for: Metric.self, inMemory: true)
}

 
 
