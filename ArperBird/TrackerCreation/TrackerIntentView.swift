//
//  TrackerIntentView.swift
//  ArperBird
//
//  Created by Olivier Picard on 05/07/2026.
//

import PostHog
import SwiftUI
#if DEBUG
import FirebaseCore
#endif

/// UI-only mockup of the intent-based creation screen, prompt-first: a free-text
/// "describe it" field on top with quick-fill chips (a fresh per-visit sample of
/// the curated suggestions, one per kind), and the live preview card below as
/// the response, re-shaped by format pills. No AI, no navigation, no
/// persistence — built to evaluate the design before committing.
struct TrackerIntentView: View {
    @State private var suggestions: [IntentSuggestion]
    @State private var placeholder: Metric
    @State private var selected: IntentSuggestion?
    @State private var formatIndex = 0
    @State private var isLoading = false
    @State private var isFailed = false
    @State private var text = ""
    @State private var promptIndex = 0
    /// True while a real category fetch is in flight for the typed/free-text
    /// path's "choices" format — see `loadRealCategoriesIfNeeded`. Drives the
    /// redacted look on that one format's preview without holding up the rest
    /// of the resolved suggestion.
    @State private var categoriesLoading = false
    /// How the current `selected` suggestion was resolved — "chip" for a
    /// curated tap (or a pre-resolved dashboard badge seed), "typed" for the
    /// free-text AI path. Read by `continueWithSelection()` to tag
    /// `tracker_kind_selected`.
    @State private var selectionSource: String
    @FocusState private var isFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// AI seam: interprets the free-text field into a titled intent + formats.
    /// Injected so previews drive the fake without a network round-trip.
    private let generateIntent: (String) async throws -> IntentCompletion

    /// The flow's shared state — only reached for here to fetch real
    /// categories (via `TrackerCreationModel.loadCategoryIfNeeded()`) once the
    /// typed/free-text path resolves to a "choices" format, so the preview
    /// shows real labels instead of "Example 1, 2…". The same memoized fetch
    /// backs the later category-config step, so continuing into it never
    /// re-hits the AI for the same name. Defaults to a scratch model for
    /// previews / the curated-chip path, which never touches it.
    private let model: TrackerCreationModel

    /// Hands the resolved pick to the creation flow: the chosen format's kind,
    /// the intent name, the per-kind color the preview showed, and — only for
    /// a "choices" format with a premade set (a curated suggestion) — its
    /// category labels, single/multiple flag, and emoji, so the flow can seed
    /// the choices path directly instead of firing its own AI fetch. Empty
    /// labels for every other format, and for the free-text AI path (which has
    /// no premade set of its own). The flow routes into the kind's step
    /// machinery from here.
    private let onContinue: (TrackerKind, String, Color, [String], Bool, String) -> Void

    /// When true, raise the keyboard and focus the field as the screen appears
    /// — used by the empty-dashboard launcher so a tap lands straight in typing.
    /// (Focusing freezes the placeholder rotation, which is the intended trade.)
    private let autofocusField: Bool

    /// Rotating placeholder examples, each completing the fixed "Track" prefix
    /// — and each quietly demoing a different answer shape (number, duration,
    /// yes/no, choices, goal, date).
    static let examplePrompts: [LocalizedStringKey] = [
        "how many coffees I drink",
        "time spent reading",
        "if I stretched",
        "my mood today",
        "glasses of water drunk",
        "when I watered the plants",
    ]

    @MainActor
    init(
        preselected: TrackerSuggestion? = nil,
        autofocusField: Bool = false,
        model: TrackerCreationModel? = nil,
        generateIntent: @escaping (String) async throws -> IntentCompletion = {
            try await IntentAiCompletion().generate(for: $0)
        },
        onContinue: @escaping (TrackerKind, String, Color, [String], Bool, String) -> Void = {
            _, _, _, _, _, _ in
        }
    ) {
        self.autofocusField = autofocusField
        // Nil (the curated-chip path and every preview but the flow's own)
        // just means "no reuse target" — a scratch model that's never touched.
        self.model = model ?? TrackerCreationModel()
        self.generateIntent = generateIntent
        self.onContinue = onContinue
        // A dashboard badge tap arrives pre-resolved: build the curated
        // suggestion up front (no AI) so the card and format pills show on open,
        // exactly as if the user had tapped an in-screen chip and it settled.
        let preresolved = preselected.map(Self.intentSuggestion(from:))
        _selected = State(initialValue: preresolved)
        _text = State(initialValue: Self.stripTrackPrefix(preresolved?.instruction ?? ""))
        _selectionSource = State(initialValue: preselected != nil ? "chip" : "typed")
        _suggestions = State(initialValue: Self.makeSuggestions())
        _placeholder = State(
            initialValue: Metric(
                from: MetricSchema.Fake.number(
                    title: String(localized: "Your tracker name"),
                    emoji: "🫥",
                    goal: nil,
                    chart: .line
                ),
                color: .gray,
                data: Self.calmPlaceholderData()
            )
        )
    }

    private var displayedMetric: Metric {
        guard let selected, !isLoading else { return placeholder }
        return selected.formats[formatIndex].metric
    }

    /// The preview card's color — the resolved suggestion's, passed through the
    /// readability filter so the card, its chart, and the controls all share
    /// the same corrected shade. Gray while the card is still the ghost.
    private var mainColor: Color {
        guard let selected, !isLoading else { return .gray }
        return selected.color.readableControlTint(in: colorScheme)
    }

    var body: some View {
        // A scroll view (not a static VStack) so the large title collapses as
        // content rises and keyboard avoidance scrolls *within* the content
        // instead of shoving the field up under the title bar. The CTA is
        // docked separately via `.safeAreaInset` so it stays pinned.
        ScrollView {
            VStack(spacing: 0) {

                inputField
                    .padding(.horizontal)
                    .padding(.top, 30)

                // Quick-fill examples for the field: a tap fills the prompt, then
                // the card below resolves — teaching the field→card causality.
                BadgesStackView(
                    badges: suggestions.map(\.chipLabel),
                    innerPadding: 5,
                    borderThickness: 0.5,
                    alignment: .center,
                    maxRows: 2,
                    onTap: { index in resolve(suggestions[index]) }
                )
                .font(.footnote)
                .padding(.horizontal)
                .padding(.top, 14)

                // The response zone, anchored to the prompt cluster above: a label
                // that names the zone (and explains the ghost card), the card, and
                // its format pills directly beneath it.
                Text(responseZoneLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)

                Group {
                    if isFailed {
                        failureCard
                    } else {
                        previewCard
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                formatPills
                    .padding(.top, 14)
                    .padding(.bottom, 24)
            }
        }
        // Drag down over the content to dismiss the keyboard.
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: continueWithSelection) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            // The tracker's color owns the accent from the moment the card
            // resolves: the CTA picks up the card's corrected shade alongside
            // the preview. `mainColor` is gray until then, matching the
            // neutral ghost state.
            .tint(mainColor)
            .disabled(selected == nil || isLoading || isFailed || isChoicesPreviewLoading)
            .padding()
        }
        // Let the keyboard cover the CTA while typing: the whole layout ignores
        // the keyboard safe area, so the docked button stays pinned to the
        // screen bottom instead of riding up above the keyboard.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle("Add a tracker")
        .navigationSubtitle("What do you want to track ?")
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard autofocusField else { return }
            // A short beat lets the sheet's present transition settle; focusing
            // mid-transition is dropped and the keyboard never rises.
            try? await Task.sleep(for: .seconds(0.35))
            isFieldFocused = true
        }
        .trackScreen("ManualTrackerCreationIntent")
    }

    // MARK: - Subviews

    private var responseZoneLabel: LocalizedStringKey {
        if isLoading { return "Creating your tracker…" }
        if isFailed { return "Hmm, that didn't go through" }
        return selected == nil
            ? "Your tracker will appear here"
            : "You, three weeks from now"
    }
 
    private var cardBody: some View {
        MetricView(
            mainColor: mainColor,
            header: {
                MetricHeaderTextView(
                    title: displayedMetric.name,
                    emoji: displayedMetric.emoji,
                    mainColor: mainColor,
                )
            },
            // Override the metric's stored raw color so the chart renders in
            // the same corrected shade as the rest of the card.
            chart: MiniChartFactory.make(
                from: displayedMetric,
                colorOverride: mainColor
            )
        )
        .redacted(reason: isLoading || isChoicesPreviewLoading ? .placeholder : [])
    }

    private var previewCard: some View {
        Group {
            if isChoicesPreviewLoading {
                // A `TimelineView` clock drives the pulse directly, frame by
                // frame — unlike `withAnimation(.repeatForever())`, it can't
                // leak into unrelated state-driven animations elsewhere on
                // screen (e.g. the CTA button, which visibly started
                // swinging when the pulse was done that way).
                TimelineView(.animation) { context in
                    cardBody.opacity(Self.pulseOpacity(at: context.date))
                }
            } else {
                // The ghost is a promise, not a dead widget — keep it quiet.
                cardBody.opacity(selected == nil || isLoading ? 0.55 : 1)
            }
        }
        .animation(.snappy, value: isLoading)
        .animation(.snappy, value: isChoicesPreviewLoading)
    }

    /// A smooth 0.4–0.7 sine pulse, ~1.8s period — driven directly off the
    /// `TimelineView` clock rather than SwiftUI's implicit animation system,
    /// so it can't leak into unrelated state-driven animations elsewhere.
    private static func pulseOpacity(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let phase = (sin(t * 2 * .pi / 1.8) + 1) / 2
        return 0.4 + phase * 0.3
    }

    /// True while the *displayed* format is "choices" and its real categories
    /// are still being fetched — redacts just that one preview instead of
    /// holding up the whole resolved suggestion.
    private var isChoicesPreviewLoading: Bool {
        guard let selected, !isLoading else { return false }
        return categoriesLoading && selected.formats[formatIndex].kind == .choices
    }

    /// Dedicated failure state for the card slot: replaces the preview card in
    /// the exact same footprint (a hidden preview card reserves the frame) so
    /// the response zone never jumps. Muted on purpose — a hiccup, not a loss.
    private var failureCard: some View {
        previewCard
            .hidden()
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    Text("Couldn't reach the AI")
                        .font(.headline)
                    Text("Check your connection and try again")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: { resolveCustom() }) {
                        Label("Try again", systemImage: "arrow.clockwise")
                            .font(.footnote.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.gray)
                    .padding(.top, 8)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Couldn't reach the AI for now. Try again later.")
    }

    /// One pill per way this suggestion can be logged; tapping re-shapes the
    /// preview instantly (in the real flow this is a local morph, no AI).
    private var formatPills: some View {
        WrappingHStack(alignment: .center, hSpacing: 8, vSpacing: 8) {
            if let selected, !isLoading, !isFailed {
                ForEach(selected.formats.indices, id: \.self) { index in
                    let format = selected.formats[index]
                    // True only for the "choices" pill while its real
                    // categories are still in flight — swaps its icon for a
                    // spinner so the wait is legible at the pill itself, not
                    // just on the card.
                    let isPillLoading = categoriesLoading && format.kind == .choices
                    Button(action: { selectFormat(at: index, in: selected) }) {
                        Label {
                            Text(format.label)
                        } icon: {
                            if isPillLoading {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: format.icon)
                            }
                        }
                        .font(.footnote.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    // The selected pill shares the card's corrected shade.
                    .tint(index == formatIndex ? mainColor : .gray)
                }
            } else {
                // Reserve the row's height so the layout doesn't jump.
                Button(action: {}) {
                    Label("placeholder", systemImage: "circle")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.bordered)
                .hidden()
            }
        }
    }

    private var inputField: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(inputFieldLitTint)
            // "Track" is its own view, so it's inherently non-deletable —
            // mirrors `TrackerInputFieldCTA`'s split-field layout, forcing
            // every typed prompt to read as "Track …". Dimmed to placeholder
            // tint at rest, lights up to real-text tint on focus or once
            // something's typed — same cue as the CTA field.
            Text("Track")
                .foregroundStyle(inputFieldLitTint)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(Self.examplePrompts[promptIndex])
                        .id(promptIndex)
                        .foregroundStyle(Color(.placeholderText))
                        .transition(
                            reduceMotion ? .opacity : .push(from: .bottom)
                        )
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { resolveCustom() }
                    .accessibilityLabel("Describe what you want to track")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemFill))
        )
        .animation(.easeInOut(duration: 0.35), value: isFieldFocused)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard text.isEmpty, !isFieldFocused else { continue }
                withAnimation(.snappy) {
                    promptIndex = (promptIndex + 1) % Self.examplePrompts.count
                }
            }
        }
    }

    /// "Track" + sparkles tint for `inputField`: real-text color when focused
    /// or once something's typed, placeholder gray otherwise — the same "lit"
    /// cue as `TrackerInputFieldCTA.litTint`.
    private var inputFieldLitTint: Color {
        isFieldFocused || !text.isEmpty ? .primary : Color(.placeholderText)
    }

    /// Hands the current pick off to the creation flow: the selected format's
    /// kind (which path to route into), the intent name, its color, and — for
    /// a "choices" format with a premade set — the categories themselves, so
    /// the flow can seed them directly instead of firing its own AI fetch.
    private func continueWithSelection() {
        guard let selected, !isLoading, !isFailed else { return }
        let format = selected.formats[formatIndex]
        var properties: [String: Any] = [
            "kind": format.kind.rawValue,
            "via": selectionSource,
        ]
        // Only a curated chip has a catalog id to attribute the pick to — an AI
        // free-text resolution has none, so the property is omitted rather than
        // sent as a placeholder.
        if let suggestionID = selected.suggestionID {
            properties["suggestion_id"] = suggestionID
        }
        PostHogSDK.shared.capture("tracker_kind_selected", properties: properties)
        onContinue(
            format.kind,
            selected.trackerName,
            selected.color,
            format.categoryLabels,
            format.categoryAllowsMultiple,
            selected.emoji
        )
    }

    /// Reports a format-pill switch — deliberation between how a resolved idea
    /// should be logged (e.g. "Daily goal" vs "A number") that `tracker_kind_selected`
    /// alone can't see, since that only fires once at the very end on "Continue".
    /// A same-index tap (re-selecting the active pill) is a no-op, so it isn't
    /// reported.
    private func selectFormat(at index: Int, in suggestion: IntentSuggestion) {
        guard index != formatIndex else { return }
        PostHogSDK.shared.capture(
            "tracker_format_switched",
            properties: [
                "from_kind": suggestion.formats[formatIndex].kind.rawValue,
                "to_kind": suggestion.formats[index].kind.rawValue,
            ]
        )
        formatIndex = index
    }

    // MARK: - Fake resolution (stands in for the AI classify call)

    private func resolve(_ suggestion: IntentSuggestion) {
        text = Self.stripTrackPrefix(suggestion.instruction)
        isFailed = false
        isLoading = true
        categoriesLoading = false
        selectionSource = "chip"
        // Reports the tap itself (not just an eventual "Continue"), mirroring
        // `EmptyDashboardView`'s `empty_dashboard_chip_tapped` — lets a curated
        // idea's explore rate be compared against its eventual conversion via
        // `tracker_kind_selected`'s `suggestion_id`. `suggestion.suggestionID` is
        // always set here since `resolve` only ever receives curated chips
        // (never the AI free-text path).
        PostHogSDK.shared.capture(
            "tracker_intent_chip_tapped",
            properties: ["suggestion_id": suggestion.suggestionID ?? "unknown"]
        )
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            formatIndex = 0
            selected = suggestion
            isLoading = false
        }
    }

    /// Free-text resolution: hands the typed prompt to the AI, which returns a
    /// title, emoji, and the formats that best fit it. On failure the card slot
    /// shows the dedicated failure card; the prompt stays in the field, so
    /// "Try again" (or return) re-submits it.
    private func resolveCustom() {
        let name = text.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isFieldFocused = false
        isFailed = false
        isLoading = true
        categoriesLoading = false
        Task {
            let start = ContinuousClock.now
            do {
                let completion = try await generateIntent(name)
                let elapsed = ContinuousClock.now - start
                PostHogSDK.shared.capture(
                    "tracker_ai_completion_succeeded",
                    properties: [
                        "facet": "intent",
                        "duration_s": ((elapsed / .seconds(1)) * 10).rounded() / 10,
                    ]
                )
                formatIndex = 0
                let suggestion = intentSuggestion(from: completion)
                selected = suggestion
                selectionSource = "typed"
                loadRealCategoriesIfNeeded(for: suggestion)
            } catch {
                let elapsed = ContinuousClock.now - start
                PostHogSDK.shared.capture(
                    "tracker_ai_completion_failed",
                    properties: [
                        "facet": "intent",
                        "duration_s": ((elapsed / .seconds(1)) * 10).rounded() / 10,
                    ]
                )
                PostHogSDK.shared.captureException(error, properties: ["facet": "intent"])
                selected = nil
                isFailed = true
            }
            isLoading = false
        }
    }

    /// Fires a real category fetch for `suggestion`'s "choices" format, if it
    /// has one — replacing its generic "Example 1, 2…" preview once real
    /// labels land, without holding up the number/duration/etc. pills that
    /// already show. Reuses `TrackerCreationModel.loadCategoryIfNeeded()`, the
    /// same memoized call the later category-config step makes, so nothing is
    /// re-fetched if the user actually continues into "Pick from a list". A
    /// failure here is silent — the generic placeholder just stays put, since
    /// this is a preview nicety, not a step the user can retry.
    private func loadRealCategoriesIfNeeded(for suggestion: IntentSuggestion) {
        guard let index = suggestion.formats.firstIndex(where: { $0.kind == .choices })
        else { return }
        categoriesLoading = true
        Task {
            model.name = suggestion.trackerName
            await model.loadCategoryIfNeeded()
            // The user may have typed something else while this was in
            // flight — only apply the result if it's still on screen.
            guard selected?.id == suggestion.id else { return }
            categoriesLoading = false
            guard model.categoryPhase == .loaded else { return }
            selected?.formats[index] = Self.choicesIntentFormat(
                name: suggestion.trackerName,
                emoji: suggestion.emoji,
                color: suggestion.color,
                labels: model.categoryLabels,
                allowsMultiple: model.categoryAllowsMultiple
            )
        }
    }

    /// Turns the AI's interpreted intent into the local `IntentSuggestion` the
    /// preview card and format pills already render.
    private func intentSuggestion(from completion: IntentCompletion) -> IntentSuggestion {
        let color = Self.color(for: completion.formats.first?.kind ?? .number)
        return IntentSuggestion(
            // AI free-text resolution has no catalog entry to attribute to.
            suggestionID: nil,
            trackerName: completion.title,
            instruction: completion.title,
            emoji: completion.emoji,
            chipLabel: "\(completion.title) \(completion.emoji)",
            color: color,
            formats: completion.formats.map {
                Self.intentFormat(
                    for: $0,
                    name: completion.title,
                    emoji: completion.emoji,
                    color: color
                )
            }
        )
    }

    // MARK: - Hardcoded suggestions

    private struct IntentFormat {
        let label: String
        let icon: String
        /// The tracker kind this format resolves to — handed to `onContinue` so
        /// the creation flow knows which path to route into.
        let kind: TrackerKind
        let metric: Metric
        /// Premade categories for a "choices" format, carried through from
        /// `TrackerSuggestion.categoryLabels` — handed to `onContinue` so the
        /// creation flow can seed the choices path directly instead of firing
        /// its own AI fetch. Empty for every other format, and for the
        /// free-text AI path (which has no premade set of its own).
        var categoryLabels: [String] = []
        var categoryAllowsMultiple = false
    }

    private struct IntentSuggestion: Identifiable {
        let id = UUID()
        /// The curated `TrackerSuggestion.id` this came from, for analytics —
        /// lets `tracker_kind_selected` (and the chip-tap event) attribute a
        /// pick to a specific curated idea. Nil for an AI free-text resolution,
        /// which has no catalog entry to point at.
        let suggestionID: String?
        let trackerName: String
        /// The sentence offered as the field's prompt text — distinct from
        /// `trackerName` so the card can carry a concise name while the field
        /// reads as a full sentence. Equal to `trackerName` when a suggestion
        /// has no natural sentence of its own.
        let instruction: String
        let emoji: String
        /// Short chip text — may be shorter than `trackerName` (e.g. "Practice"
        /// vs "Music Practice").
        let chipLabel: String
        let color: Color
        /// `var`, not `let` — `loadRealCategoriesIfNeeded` replaces the
        /// "choices" entry in place once its real categories land.
        var formats: [IntentFormat]
    }

    /// A calm, slow swell for the ghost card — deliberately unlike real data so
    /// the placeholder reads as "awaiting", not as a noisy dead widget.
    private static func calmPlaceholderData(days: Int = 22) -> [DataPoint] {
        let calendar = Calendar.current
        return (0..<days).map { day in
            let date = calendar.date(byAdding: .day, value: -day, to: .now) ?? .now
            let phase =  Double.pi
            let value = 50 + 8 * sin(Double(day) / 2.5 + phase)
            return .number(date, value)
        }
    }

    private static func metric(
        _ schema: MetricSchema,
        color: Color,
        days: Int = 14
    ) -> Metric {
        Metric(
            from: schema,
            color: color,
            data: Metric.fakeData(for: schema.config, days: days)
        )
    }

    /// One random curated example per kind (drawn from the type-picker's
    /// pools), in shuffled order — a fresh set each visit that always spans
    /// every tracker kind.
    private static func makeSuggestions() -> [IntentSuggestion] {
        TrackerKind.allCases
            .compactMap { TrackerSuggestion.examples(for: $0).randomElement() }
            .shuffled()
            .map(intentSuggestion(from:))
    }

    /// Card tint per kind, standing in for the color the AI would pick.
    private static func color(for kind: TrackerKind) -> Color { kind.previewColor }

    /// Strips a leading "Track " (resolved in the current locale, e.g.
    /// "Note "/"Anota ") from a curated suggestion's instruction before it
    /// seeds the field's editable text — the field itself now supplies that
    /// word as a static, non-deletable prefix (see `inputField`), so keeping
    /// it in `text` too would read "Track Track the water I drink".
    private static func stripTrackPrefix(_ instruction: String) -> String {
        let trackPrefix = String(localized: "Track") + " "
        guard instruction.hasPrefix(trackPrefix) else { return instruction }
        return String(instruction.dropFirst(trackPrefix.count))
    }

    /// Fake resolution for a curated suggestion: builds a pill + preview card
    /// for each of the suggestion's own `formats`, seeded with its name and
    /// emoji. The card tint follows the first (best-fit) format so a goal-led
    /// idea like water opens tinted as a goal, not its underlying number.
    private static func intentSuggestion(
        from suggestion: TrackerSuggestion
    ) -> IntentSuggestion {
        let color = color(for: suggestion.formats.first?.kind ?? .number)
        return IntentSuggestion(
            suggestionID: suggestion.id,
            trackerName: suggestion.localizedTrackerName,
            instruction: suggestion.localizedInstruction,
            emoji: suggestion.emoji,
            chipLabel: suggestion.chipText,
            color: color,
            formats: suggestion.formats.map {
                intentFormat(
                    for: $0,
                    name: suggestion.localizedTrackerName,
                    emoji: suggestion.emoji,
                    color: color,
                    categoryLabels: suggestion.categoryLabels,
                    categoryAllowsMultiple: suggestion.categoryAllowsMultiple
                )
            }
        )
    }

    /// Rebuilds the "choices" format's pill + preview card with real,
    /// AI-fetched category labels (and the matching single/multiple chart) —
    /// what `loadRealCategoriesIfNeeded` swaps in once the fetch lands, in
    /// place of `intentFormat(for: .choices, …)`'s generic placeholder.
    private static func choicesIntentFormat(
        name: String,
        emoji: String,
        color: Color,
        labels: [String],
        allowsMultiple: Bool
    ) -> IntentFormat {
        let schema =
            allowsMultiple
            ? MetricSchema.Fake.categoryMultiple(
                title: name,
                emoji: emoji,
                labels: labels,
                chart: .bar
            )
            : MetricSchema.Fake.categorySingle(
                title: name,
                emoji: emoji,
                labels: labels,
                chart: .pie
            )
        return IntentFormat(
            label: String(localized: "Pick from a list"),
            icon: "list.bullet",
            kind: .choices,
            metric: metric(schema, color: color)
        )
    }

    /// Builds a single pill + preview card for one logging format. Shared by
    /// the curated chip path (`formats(for:)`) and the AI free-text path
    /// (`intentSuggestion(from:)`).
    private static func intentFormat(
        for type: IntentFormatType,
        name: String,
        emoji: String,
        color: Color,
        categoryLabels: [String] = [],
        categoryAllowsMultiple: Bool = false
    ) -> IntentFormat {
        switch type {
        case .duration:
            IntentFormat(
                label: String(localized: "Time spent"),
                icon: "clock",
                kind: type.kind,
                metric: metric(
                    MetricSchema.Fake.duration(
                        title: name,
                        emoji: emoji,
                        chart: .bar
                    ),
                    color: color,
                    days: 40
                )
            )
        case .binary:
            IntentFormat(
                label: String(localized: "Yes / No"),
                icon: "checkmark.circle",
                kind: type.kind,
                metric: metric(
                    MetricSchema.Fake.binary(
                        title: name,
                        emoji: emoji,
                        chart: .calendar
                    ),
                    color: color
                )
            )
        case .number:
            IntentFormat(
                label: String(localized: "A number"),
                icon: "number",
                kind: type.kind,
                metric: metric(
                    MetricSchema.Fake.number(
                        title: name,
                        emoji: emoji,
                        goal: nil,
                        chart: .bar
                    ),
                    color: color,
                    days: 40
                )
            )
        case .goal:
            IntentFormat(
                label: String(localized: "Daily goal"),
                icon: "target",
                kind: type.kind,
                metric: metric(
                    MetricSchema.Fake.number(
                        title: name,
                        emoji: emoji,
                        min: 0,
                        max: 10,
                        granularity: 1,
                        goal: 8,
                        chart: .dailyGauge
                    ),
                    color: color
                )
            )
        case .choices:
            // A curated suggestion carries its own premade `categoryLabels` —
            // shown as-is, no AI fetch needed (see `TrackerSuggestion.categoryLabels`).
            // The free-text AI path has none yet, so it still falls back to the
            // generic placeholder until `loadRealCategoriesIfNeeded` lands.
            IntentFormat(
                label: String(localized: "Pick from a list"),
                icon: "list.bullet",
                kind: type.kind,
                metric: categoryLabels.isEmpty
                    ? metric(
                        MetricSchema.Fake.categorySingle(
                            title: name,
                            emoji: emoji,
                            chart: .pie
                        ),
                        color: color
                    )
                    : metric(
                        categoryAllowsMultiple
                            ? MetricSchema.Fake.categoryMultiple(
                                title: name,
                                emoji: emoji,
                                labels: categoryLabels,
                                chart: .bar
                            )
                            : MetricSchema.Fake.categorySingle(
                                title: name,
                                emoji: emoji,
                                labels: categoryLabels,
                                chart: .pie
                            ),
                        color: color
                    ),
                categoryLabels: categoryLabels,
                categoryAllowsMultiple: categoryAllowsMultiple
            )
        case .date:
            IntentFormat(
                label: String(localized: "A date"),
                icon: "calendar",
                kind: type.kind,
                metric: metric(
                    MetricSchema.Fake.datetime(
                        title: name,
                        emoji: emoji,
                        chart: .calendar
                    ),
                    color: color
                )
            )
        }
    }

}

/// Every submit fails after the usual "thinking" beat — type anything and hit
/// return to land on the failure card.
#Preview("Failure") {
    NavigationStack {
        TrackerIntentView(
            generateIntent: { _ in
                try await Task.sleep(for: .seconds(0.7))
                throw URLError(.notConnectedToInternet)
            }
        )
    }
    .environment(\.locale, Locale(identifier: "en_US"))
}

/// Arrives pre-resolved, as if opened from a tapped dashboard badge: the field
/// is filled and the preview card + format pills show immediately, no loading.
#Preview("Preselected") {
    NavigationStack {
        // A goal-led badge: opens on "Daily goal" (its first format), tinted as
        // a goal, with "A number" as the sensible alternate.
        TrackerIntentView(
            preselected: .init(
                label: "Water",
                trackerName: "Glasses of Water",
                emoji: "💧",
                kind: .number,
                formats: [.goal, .number]
            )
        )
    }
    .environment(\.locale, Locale(identifier: "en_US"))
}

#Preview("Fake AI") {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerIntentView(
                generateIntent: { try await IntentAiCompletion().generateFake(for: $0) }
            )
        }
        .environment(\.locale, Locale(identifier: "en_US"))
    }
    .presentationDetents([.large])
}

#if DEBUG
/// Drives the real Firebase AI completion on submit. Configures Firebase
/// itself since the AppDelegate doesn't run in previews.
#Preview("Real AI") {
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    return NavigationStack {
        TrackerIntentView()
    }
    .environment(\.locale, Locale(identifier: "en_US"))
}
#endif
