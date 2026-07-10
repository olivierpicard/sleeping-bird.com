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
    /// What a keyboard submit does — injected by the parent.
    let onSubmit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Which rotating example prompt shows as placeholder. Field-local.
    @State private var promptIndex = 0

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
                        .onSubmit(onSubmit)
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
        .glowBorder(
            palette: .iris, style: .edgeOnly, period: 13.0, cornerRadius: 16,
            isActive: isFocused
        )
        // Tapping anywhere on the field chrome focuses it (the inner tap wins
        // over the content's dismiss tap).
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .animation(.easeInOut(duration: 0.35), value: isFocused)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                // Freeze rotation while focused or mid-typing.
                guard !isFocused, draft.isEmpty else { continue }
                withAnimation(.snappy) {
                    promptIndex =
                        (promptIndex + 1) % TrackerIntentView.examplePrompts.count
                }
            }
        }
    }

    /// "Track" + sparkles tint: real-text color when focused ("lit"), placeholder
    /// gray otherwise. Transitions are animated via the field's `.animation`.
    private var litTint: Color {
        isFocused ? .primary : Color(.placeholderText)
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
