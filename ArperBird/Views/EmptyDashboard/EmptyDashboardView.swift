//
//  EmptyDashboardView.swift
//  ArperBird
//
//  Created by Olivier Picard on 24/04/2026.
//

import PostHog
import SwiftUI

/// The empty-state dashboard, redesigned to the "minimal" direction in
/// [decision 0006]: a soft glyph, a centered gradient headline, the field as the
/// primary CTA, and the kept suggestion chips — all over the sunrise background
/// that `ContentView` supplies (kept shared, not applied here).
///
/// Every entry point routes through `onAddMetric`: the field CTA opens the
/// creation flow from scratch (`nil`) so a tap lands straight in typing, and a
/// chip *types itself into the field* (keyboard stays down) before opening the
/// flow seeded with that pick. The chips read as fillable examples of what to
/// type — a "Try one:" label names them, and a tight sub-block binds the
/// field → label → chips by proximity.
///
/// Layout knobs live in `Tuning`; every piece is its own `@ViewBuilder`.
struct EmptyDashboardView: View {
    /// Plays the block-by-block entrance stagger on appear. Only `RootView`'s
    /// onboarding hand-off sets this — a regular cold launch (or emptying the
    /// dashboard) shows everything immediately, no replay.
    var animatesEntrance = false

    /// Opens the creation flow — seeded with the tapped suggestion, or from
    /// scratch (`nil`) via the field CTA.
    let onAddMetric: (TrackerSuggestion?) -> Void

    /// Runs a single-format chip's first AI load *during* the "preparing" glow,
    /// so the flow it opens can skip its own loading spinner rather than stacking
    /// a second one behind the glow. Called only for single-format suggestions;
    /// multi-format chips open on the interactive format picker, which needs no
    /// prefetch. Returns whether the prefetch succeeded — `false` surfaces the
    /// same inline retry message as a failed `resolveIntent` instead of opening
    /// the flow. A no-op `true` default keeps the view previewable standalone.
    var prepareSeed: (TrackerSuggestion) async -> Bool = { _ in true }

    /// Resolves the free-text draft into a `TrackerSuggestion` (title, emoji, and
    /// the logging formats that fit it) via the intent AI, so a typed prompt can
    /// route through the same seeded flow the chips use. Throws on failure, which
    /// surfaces the inline retry state. A throwing default keeps the view
    /// previewable standalone; callers (and previews) inject the real/fake seam.
    var resolveIntent: (String) async throws -> TrackerSuggestion = { _ in
        throw CancellationError()
    }

    @Environment(\.colorScheme) private var colorScheme

    /// The real text the user types into the CTA field, owned here so the
    /// full-screen dismiss gestures and the field share the same focus/draft.
    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool

    /// The in-flight "type a chip into the field" animation, held so a second
    /// chip tap (or leaving the view) cleanly cancels the first.
    @State private var typeTask: Task<Void, Never>?

    /// True while a chip is typing itself in — lights the field's glow without
    /// focusing it (which would raise the keyboard).
    @State private var isTyping = false

    /// Keeps the completed chip text on screen while its CTA changes to the
    /// inward loading glow, immediately before opening the creation sheet.
    @State private var isPreparingCreation = false

    /// How many blocks of the entrance stagger have landed (glyph → headline →
    /// subcopy → field → chips). Only advanced when `animatesEntrance`;
    /// otherwise `hasEntered` short-circuits and every block is visible.
    @State private var entranceStage = 0

    /// True when the last field submit couldn't reach the intent AI — surfaces a
    /// brief inline retry message under the field. Cleared as soon as the user
    /// edits the draft or resubmits, so it never lingers past a fresh attempt.
    @State private var submitFailed = false

    /// All the spacings / sizes / copy in one place so the layout can be dialed
    /// in without hunting through the view tree.
    private enum Tuning {
        static let outerSpacing: CGFloat = 24
        static let glyphDash: [CGFloat] = [5, 5]
        static let chipRows = 3

        static let glyph = "📈"

        /// Opacity of the neutral scrim that dims the shared background while the
        /// field is focused (or a chip is typing itself in), so the glowing CTA
        /// carries the eye.
        static let focusedBackdropDim: Double = 0.6

        /// Spacing inside the tight sub-block (field → label → chips) so
        /// proximity binds them together.
        static let tightGroupSpacing: CGFloat = 20

        // Chip sizing — smaller than `BadgesStackView`'s defaults so the chips
        // read as lightweight examples, not primary buttons.
        static let chipFont: Font = .footnote
        static let chipInnerPadding: Double = 5
        static let chipCornerRadius: Double = 12

        /// Timing for the chip-to-field animation. Letter timing is varied in
        /// `typingDelay` below; these pauses make the completed phrase readable
        /// before the tracker flow opens.
        static let typeStartDelay: Duration = .milliseconds(300)
        static let typeSettleDelay: Duration = .milliseconds(750)
        static let creationLoadingDelay: Duration = .seconds(3)
    }

    /// The curated suggestion chips — the same source `TrackerIntentView` samples
    /// from. Shown in full (not a clipped few) so the field's range of ideas reads.
    private let suggestions = TrackerSuggestion.defaults

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Dismiss the keyboard by tapping empty space or swiping down. Both
            // hang off the full-screen frame; the field's own tap (focus) and the
            // chips' taps are more specific, so they still win.
            .contentShape(Rectangle())
            .onTapGesture {
                if isFieldFocused, !draft.isEmpty {
                    PostHogSDK.shared.capture(
                        "empty_dashboard_draft_abandoned",
                        properties: ["length": draft.count]
                    )
                }
                isFieldFocused = false
            }
            .padding()
            // When the field lights up, knock the shared mesh background back so
            // the glowing CTA carries the focus. The background itself lives in
            // `ContentView`; this scrim sits between it and the content. A
            // `systemBackground` fill mirrors how the mesh fades toward neutral
            // (near-black in dark, near-white in light), reading as dimmed rather
            // than a foreign overlay.
            .background {
                Color(.systemBackground)
                    .opacity(isFieldFocused || isTyping ? Tuning.focusedBackdropDim : 0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.35), value: isFieldFocused)
                    .animation(.easeInOut(duration: 0.35), value: isTyping)
            }
            // Any edit to the draft clears a stale failure message, so it never
            // lingers past a fresh attempt.
            .onChange(of: draft) {
                if submitFailed { submitFailed = false }
            }
            .animation(.easeInOut(duration: 0.25), value: submitFailed)
            // A dismissed view must not keep mutating `draft`.
            .onDisappear {
                typeTask?.cancel()
                isTyping = false
                isPreparingCreation = false
            }
            .trackScreen("EmptyDashboard")
    }

    // MARK: - Field submit → intent resolution

    /// Resolves whatever the user typed into a `TrackerSuggestion`, then opens the
    /// creation flow seeded with it — the free-text counterpart to a chip tap. The
    /// AI resolution runs *under* the field's inward loading glow (kept alive by
    /// `isPreparingCreation`), overlapping the field CTA's own read beat. On
    /// success it hands off exactly like `typeSuggestion`'s tail: a single-format
    /// idea prefetches its first facet so the flow skips its spinner; a
    /// multi-format idea opens on the format picker. On failure the glow drops and
    /// the inline retry message shows, with the draft preserved so a resubmit (or
    /// edit) tries again. Replaces any in-flight submit/typing task.
    private func submitDraft() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        typeTask?.cancel()
        submitFailed = false
        PostHogSDK.shared.capture(
            "empty_dashboard_draft_submitted",
            properties: [
                "length": text.count,
                "word_count": text.split(separator: " ").count,
            ]
        )
        typeTask = Task { @MainActor in
            isPreparingCreation = true
            do {
                let suggestion = try await resolveIntent(text)
                if Task.isCancelled { return }
                await openSeeded(suggestion, via: "typed")
            } catch {
                if Task.isCancelled { return }
                PostHogSDK.shared.capture(
                    "empty_dashboard_intent_failed",
                    properties: ["via": "typed_intent", "length": text.count]
                )
                PostHogSDK.shared.captureException(
                    error,
                    properties: ["via": "typed_intent"]
                )
                isPreparingCreation = false
                submitFailed = true
            }
        }
    }

    /// The field submit's hand-off, mirroring `typeSuggestion`'s tail: a
    /// single-format idea prefetches its first AI facet under the glow so the flow
    /// opens past the loading spinner; a multi-format idea skips the prefetch (it
    /// opens on the interactive format picker). Then hands the seed up to open the
    /// creation flow — unless the prefetch failed, in which case the same inline
    /// retry message shows instead and the flow never opens.
    private func openSeeded(_ suggestion: TrackerSuggestion, via: String) async {
        if suggestion.formats.count == 1 {
            let seedOk = await prepareSeed(suggestion)
            if Task.isCancelled { return }
            guard seedOk else {
                PostHogSDK.shared.capture(
                    "empty_dashboard_intent_failed",
                    properties: ["via": "\(via)_prefetch", "suggestion_id": suggestion.id]
                )
                isPreparingCreation = false
                submitFailed = true
                return
            }
        }
        if Task.isCancelled { return }
        isPreparingCreation = false
        PostHogSDK.shared.capture(
            "empty_dashboard_flow_opened",
            properties: [
                "via": via,
                "suggestion_id": suggestion.id,
                "format_count": suggestion.formats.count,
            ]
        )
        onAddMetric(suggestion)
    }

    // MARK: - Chip → field animation

    /// Types `suggestion`'s prompt into the field character-by-character, then
    /// opens the creation flow seeded with it. Types the fuller
    /// `localizedInstruction` (the prompt the intent screen itself seeds), not
    /// the short chip label — minus its leading "Track " word (resolved in the
    /// current locale, e.g. "Note "/"Anota "), since the field already shows
    /// that as a static prefix (see `TrackerInputFieldCTA`); typing it again
    /// would read "Track Track the water I drink". The full `localizedInstruction`
    /// (with the verb) still seeds the creation flow / AI prompt untouched.
    /// Deliberately does *not* focus the field, so the keyboard stays down while
    /// the text writes itself. Replaces any current draft and cancels a previous
    /// in-flight animation.
    private func typeSuggestion(_ suggestion: TrackerSuggestion) {
        typeTask?.cancel()
        PostHogSDK.shared.capture(
            "empty_dashboard_chip_tapped",
            properties: [
                "suggestion_id": suggestion.id,
                "format_count": suggestion.formats.count,
            ]
        )
        typeTask = Task { @MainActor in
            isTyping = true
            draft = ""
            try? await Task.sleep(for: Tuning.typeStartDelay)
            var previousCharacter: Character?
            // Matches the "Track" prefix Text in `TrackerInputFieldCTA` — resolve
            // it the same way so the strip tracks translations automatically.
            let trackPrefix = String(localized: "Track") + " "
            var typedName = suggestion.localizedInstruction
            if typedName.hasPrefix(trackPrefix) {
                typedName.removeFirst(trackPrefix.count)
            }
            for (index, character) in typedName.enumerated() {
                try? await Task.sleep(for: typingDelay(
                    for: character,
                    previousCharacter: previousCharacter,
                    index: index
                ))
                if Task.isCancelled { return }
                draft.append(character)
                previousCharacter = character
            }
            // Hold the completed text a beat, then auto-submit into the flow.
            try? await Task.sleep(for: Tuning.typeSettleDelay)
            if Task.isCancelled { return }
            isTyping = false
            isPreparingCreation = true
            // A single-format chip skips the flow's format picker and drops
            // straight into a loading spinner — so run that AI load *now*, under
            // the glow, and let the glow double as its read beat. The
            // `creationLoadingDelay` floor keeps the completed phrase readable
            // even when the load returns fast, and the flow then opens past the
            // spinner (see `prepareSeed` / `TrackerCreationFlow`). A multi-format
            // chip opens on the interactive picker instead, so its glow stays a
            // plain fixed-length read beat — there's no prefetch to fail there.
            var seedOk = true
            if suggestion.formats.count == 1 {
                async let prep: Bool = prepareSeed(suggestion)
                try? await Task.sleep(for: Tuning.creationLoadingDelay)
                seedOk = await prep
            } else {
                try? await Task.sleep(for: Tuning.creationLoadingDelay)
            }
            if Task.isCancelled { return }
            isPreparingCreation = false
            // A failed prefetch shows the same inline retry message as a failed
            // field submit, instead of opening the flow.
            guard seedOk else {
                PostHogSDK.shared.capture(
                    "empty_dashboard_intent_failed",
                    properties: ["via": "chip_prefetch", "suggestion_id": suggestion.id]
                )
                submitFailed = true
                return
            }
            PostHogSDK.shared.capture(
                "empty_dashboard_flow_opened",
                properties: [
                    "via": "chip",
                    "suggestion_id": suggestion.id,
                    "format_count": suggestion.formats.count,
                ]
            )
            onAddMetric(suggestion)
        }
    }

    /// A fixed rhythm mimics small variations in human typing without making
    /// the interaction unpredictable. Word starts and punctuation get a little
    /// more time, so the generated phrase is easier to read at a glance.
    private func typingDelay(
        for character: Character,
        previousCharacter: Character?,
        index: Int
    ) -> Duration {
        switch character {
        case " ":
            return .milliseconds(145)
        case ",", ".", "!", "?", ":", ";":
            return .milliseconds(215)
        default:
            let rhythm = [0, 8, -5, 12, -9, 4, -3][index % 7]
            let wordStartPause = previousCharacter == " " ? 18 : 0
            return .milliseconds(72 + rhythm + wordStartPause)
        }
    }

    // MARK: - Layout

    private var content: some View {
        // Headline/glyph keep the full outer rhythm, but the field, label, and
        // chips collapse into one tight sub-block: the label names the chips as
        // examples while the small spacing binds them to the field by
        // proximity — no container box.
        VStack(spacing: Tuning.outerSpacing) {
            Spacer()
            softGlyph
                .opacity(hasEntered(1) ? 1 : 0)
                // Starts big and settles into the dashed frame — echoes the
                // center 📈 bubble that just left `StartView`.
                .scaleEffect(hasEntered(1) ? 1 : 1.5)
            headline
                .opacity(hasEntered(2) ? 1 : 0)
                .offset(y: hasEntered(2) ? 0 : 14)
            subcopy
                .opacity(hasEntered(3) ? 1 : 0)
                .offset(y: hasEntered(3) ? 0 : 14)
            VStack(spacing: Tuning.tightGroupSpacing) {
                TrackerInputFieldCTA(
                    draft: $draft,
                    isFocused: $isFieldFocused,
                    isTyping: isTyping,
                    isPreparingCreation: isPreparingCreation,
                    onSubmit: submitDraft
                )
                .opacity(hasEntered(4) ? 1 : 0)
                .offset(y: hasEntered(4) ? 0 : 14)
                if submitFailed {
                    submitFailure
                }
                labeledBadges("Try one:")
                    .opacity(hasEntered(5) ? 1 : 0)
                    .offset(y: hasEntered(5) ? 0 : 14)
            }
            Spacer()
            Spacer()
        }
        .onAppear(perform: runEntranceAnimation)
    }

    // MARK: - Entrance stagger

    /// Whether the block at `stage` has landed. Short-circuits to `true` when
    /// the entrance isn't animating, so a plain launch renders fully visible
    /// on the first frame.
    private func hasEntered(_ stage: Int) -> Bool {
        !animatesEntrance || entranceStage >= stage
    }

    /// Staggers the five blocks in, top to bottom — same vocabulary as
    /// `StartView`'s entrance (delayed springs on plain state), so the
    /// onboarding hand-off reads as one continuous scene. Each delayed
    /// `withAnimation` snapshots its own bump of `entranceStage`, so every
    /// block animates exactly when its `hasEntered` threshold flips.
    private func runEntranceAnimation() {
        guard animatesEntrance, entranceStage == 0 else { return }
        for stage in 1...5 {
            withAnimation(
                .spring(response: 0.7, dampingFraction: 0.8)
                    .delay(0.1 + Double(stage - 1) * 0.12)
            ) {
                entranceStage = stage
            }
        }
    }

    // MARK: - Blocks

    /// The two-line gradient headline.
    private var headline: some View {
        VStack(spacing: 0) {
            Text("What do you")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("want to track?")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(headlineGradient)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var subcopy: some View {
        Text("Type it in plain words — we'll build the tracker for you.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    /// The inline retry message shown when a field submit couldn't reach the
    /// intent AI. Muted on purpose — a hiccup, not a loss — mirroring the tone of
    /// `TrackerIntentView`'s failure card. The draft is preserved, so hitting
    /// return again (or editing) retries.
    private var submitFailure: some View {
        Label("Couldn't reach the AI for now. Try again later.",
              systemImage: "wifi.exclamationmark")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
    }

    /// A connective label + the kept chips, stacked. The label is what ties the
    /// chips to the field ("these are things you could type").
    private func labeledBadges(_ label: LocalizedStringKey) -> some View {
        VStack(spacing: 10) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            badges
        }
    }

    /// The kept chips. A tap types the suggestion into the field (see
    /// `typeSuggestion`), then opens the creation flow seeded with it.
    private var badges: some View {
        BadgesStackView(
            badges: suggestions.map(\.chipText),
            innerPadding: Tuning.chipInnerPadding,
            borderThickness: 0.5,
            cornerRadius: Tuning.chipCornerRadius,
            alignment: .center,
            maxRows: Tuning.chipRows,
            onTap: { index in typeSuggestion(suggestions[index]) }
        )
        .font(Tuning.chipFont)
    }

    /// A single soft glyph in a dashed frame — no data claim.
    private var softGlyph: some View {
        Text(Tuning.glyph)
            .font(.system(size: 44))
            .frame(width: 96, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        Color.secondary.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1, dash: Tuning.glyphDash)
                    )
            )
    }

    // MARK: - Styling helpers

    private var headlineGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0xe8 / 255, green: 0xee / 255, blue: 0xf4 / 255),
                   Color(red: 0xa1 / 255, green: 0xb7 / 255, blue: 0xf6 / 255)]
                : [Color(red: 0x64 / 255, green: 0x6c / 255, blue: 0xf6 / 255),
                   Color(red: 0xc2 / 255, green: 0x5d / 255, blue: 0xdd / 255)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    EmptyDashboardView(
        onAddMetric: { _ in },
        resolveIntent: { text in
            try await Task.sleep(for: .seconds(0.8))
            return TrackerSuggestion(
                from: try await IntentAiCompletion().generateFake(for: text)
            )
        }
    )
    .background { EmptyDashboardBackground() }
//    .environment(\.locale, Locale(identifier: "fr_FR"))
}

/// The block-by-block entrance played on the hand-off from onboarding.
#Preview("Onboarding hand-off") {
    EmptyDashboardView(animatesEntrance: true, onAddMetric: { _ in })
        .background { EmptyDashboardBackground() }
}

/// Type anything into the field and submit, or tap a single-format chip —
/// both `resolveIntent` and `prepareSeed` always fail, exercising the same
/// retry-message path a real network error would from either entry point.
#Preview("AI Failure") {
    EmptyDashboardView(
        onAddMetric: { _ in },
        prepareSeed: { _ in
            try? await Task.sleep(for: .seconds(0.8))
            return false
        },
        resolveIntent: { _ in
            try await Task.sleep(for: .seconds(0.8))
            throw URLError(.notConnectedToInternet)
        }
    )
    .background { EmptyDashboardBackground() }
}
