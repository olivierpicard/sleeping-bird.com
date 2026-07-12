//
//  TrackerInputFieldCTA.swift
//  ArperBird
//
//  Created by Olivier Picard on 24/04/2026.
//

import SwiftUI

/// THE primary CTA for `EmptyDashboardView` — a *real* field the user types into,
/// laid out as a static "Track" prefix + a borderless `TextField` (see the
/// split-field rationale: a single field can't cleanly protect the prefix, and
/// separate views let "Track"/sparkles animate their tint independently).
///
/// State machine, all driven by focus + emptiness:
/// - **unfocused, empty** — "Track"/sparkles dimmed to placeholder tint; the
///   `TrackerIntentView.examplePrompts` placeholder rotates.
/// - **focused** — "Track"/sparkles *light up* to real-text tint; the
///   placeholder freezes (no rotation).
/// - **typing** — the placeholder hides; clearing the field brings the
///   (frozen) placeholder back.
/// - **blur** — "Track"/sparkles fade back to the dim tint and rotation
///   resumes.
/// - **submit** — the glow flips from its slow resting *edge* rim to a fast
///   *inward* fill (a loading pulse), then dies off. Once it's off the cycle is
///   armed again, so a second submit replays it.
///
/// `draft` and `isFocused` are owned by the parent so it can still
/// tap/swipe-to-dismiss the keyboard; the placeholder rotation is field-local.
/// `onSubmit` is injected so the parent decides what a submit does.
struct TrackerInputFieldCTA: View {
    /// The real text the user types. Empty ⇒ the placeholder shows (rotating
    /// when unfocused, frozen when focused). Owned by the parent.
    @Binding var draft: String
    /// Field focus, owned by the parent so its full-screen dismiss gestures win.
    @FocusState.Binding var isFocused: Bool
    /// Lights the glow *without* focus — set while the parent is typing a chip
    /// into the field, so the field reads as active while the keyboard stays down.
    var isTyping: Bool = false
    /// Shows the inward loading glow while the parent prepares to present the
    /// creation flow (used by the chip auto-submit path).
    var isPreparingCreation: Bool = false
    /// What a keyboard submit does — injected by the parent.
    let onSubmit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Which rotating example prompt shows as placeholder. Field-local.
    @State private var promptIndex = 0

    /// While `true`, a submit is "loading": the glow becomes an inward fill
    /// circulating fast. When it flips back to `false` the glow fades off,
    /// leaving the cycle ready to replay on the next submit.
    @State private var isLoading = false

    /// Drives the glow's *style/geometry* (not its visibility). Mirrors
    /// `isLoading`, but lingers one fade-length after loading ends so the rim
    /// keeps its inward shape while it dims out. Swapping to the `.edgeOnly`
    /// geometry at the same instant the glow goes inactive makes its bloom
    /// animate its shape — it slides off diagonally instead of fading cleanly in
    /// place — so we hold the loading geometry until the opacity fade is done.
    @State private var glowShowsLoading = false

    /// Glow tuning. Resting is a slow edge rim shown only while focused; loading
    /// is a quick inward fill that runs for `loadingDuration`, then dies off.
    private enum Glow {
        static let restingPeriod: TimeInterval = 9
        static let loadingPeriod: TimeInterval = 2.5
        static let loadingDuration: TimeInterval = 1.6
        /// Matches `GlowBorder`'s internal opacity cross-fade, so the loading
        /// geometry is held exactly as long as the glow takes to dim out.
        static let fadeDuration: TimeInterval = 0.35
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(litTint)
            HStack(spacing: 4) {
                // "Track" is its own view, so it's inherently non-deletable and
                // free to animate its tint apart from the typed text.
                Text("Track")
                    .foregroundStyle(litTint)
                ZStack(alignment: .leading) {
                    if draft.isEmpty {
                        Text(TrackerIntentView.examplePrompts[promptIndex])
                            .id(promptIndex)
                            .foregroundStyle(Color(.placeholderText))
                            .transition(
                                reduceMotion ? .opacity : .push(from: .bottom)
                            )
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .foregroundStyle(.primary)
                        .submitLabel(.go)
                        .onSubmit(runSubmit)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemFill))
        )
        // Resting: a slow edge rim while focused. Loading: a fast inward fill.
        // `isActive` keeps the loading glow alive regardless of focus, then lets
        // it fade off once loading ends (falling back to the focus rim).
        .glowBorder(
            palette: .iris,
            // Visibility flips immediately (`isLoading`/`isFocused`), but the
            // *shape* follows `glowShowsLoading`, which lags through the fade so
            // the rim dims in place instead of its geometry sliding off.
            style: glowShowsLoading || isPreparingCreation ? .inward : .edgeOnly,
            period: glowShowsLoading || isPreparingCreation
                ? Glow.loadingPeriod
                : Glow.restingPeriod,
            cornerRadius: 16,
            isActive: isLoading || isPreparingCreation || isFocused || isTyping
        )
        // Tapping anywhere on the field chrome focuses it (the inner tap wins
        // over the content's dismiss tap).
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .animation(.easeInOut(duration: 0.35), value: isFocused)
        // Weld the whole field into one geometry so every layer — the box, the
        // sparkles, and the "Track" prefix — translates together when the
        // keyboard raises the layout. Without this, the `Text("Track")` drifts
        // (floats up into the field) while the box/sparkles move in lockstep,
        // because SwiftUI otherwise resolves each child's position independently
        // during the parent-driven shift.
        .geometryGroup()
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                // Freeze rotation while focused or mid-typing.
                guard !isFocused, draft.isEmpty else { continue }
                withAnimation(.snappy) {
                    promptIndex =
                        (promptIndex + 1)
                        % TrackerIntentView.examplePrompts.count
                }
            }
        }
    }

    /// A submit first runs the loading glow, then fires the parent's action.
    /// This keeps the field on screen long enough for the inward fill to read
    /// as a brief loading state before the creation sheet opens. Re-entrant
    /// submits are ignored while one is already loading.
    private func runSubmit() {
        guard !isLoading else { return }
        Task {
            isLoading = true
            glowShowsLoading = true
            try? await Task.sleep(for: .seconds(Glow.loadingDuration))
            guard !Task.isCancelled else { return }
            onSubmit()
            isLoading = false
            // Hold the inward geometry through the opacity fade, then release it.
            // Guard against a fresh submit having started during the hold.
            try? await Task.sleep(for: .seconds(Glow.fadeDuration))
            if !isLoading { glowShowsLoading = false }
        }
    }

    /// "Track" + sparkles tint: real-text color when focused ("lit"), placeholder
    /// gray otherwise. Transitions are animated via the field's `.animation`.
    private var litTint: Color {
        isFocused || !draft.isEmpty ? .primary : Color(.placeholderText)
    }
}

#Preview {
    // The field needs a `@Binding` draft and a `@FocusState.Binding`, so host it
    // in a small stateful wrapper that owns both.
    struct PreviewHost: View {
        @State private var draft = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            TrackerInputFieldCTA(
                draft: $draft,
                isFocused: $isFocused,
                onSubmit: { print("submit: \(draft)") }
            )
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Mirror the parent dashboard: tapping empty space dismisses the
            // keyboard. The field's own tap (focus) is more specific, so it wins.
            .contentShape(Rectangle())
            .onTapGesture { isFocused = false }
        }
    }

    return PreviewHost()
        .environment(\.locale, Locale(identifier: "en_US"))
}
