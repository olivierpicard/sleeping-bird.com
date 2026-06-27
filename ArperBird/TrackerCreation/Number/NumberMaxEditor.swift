//
//  NumberMaxEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// A compact bottom-sheet editor for a number tracker's maximum, raised from the
/// reveal's "Max" chip. Unlike the full `TrackerNumberMaxView` creation step, it
/// drops the `−`/`+` steppers and the question framing: the figure *is* the
/// control. It's tappable, and the keypad auto-raises on present so the user can
/// just start typing — exploratory by design. Sized to a medium detent so the
/// reveal card stays visible behind it, and the confirm button floats above the
/// keyboard via a bottom safe-area inset.
struct NumberMaxEditor: View {
    /// The unit label shown beneath the figure, or nil for a unitless tracker.
    let unit: String?
    let color: Color
    /// Commit the edited maximum. The sheet dismisses itself afterwards, so the
    /// caller only writes the value back.
    var onSave: (Double) -> Void

    @State private var value: Double
    /// The text backing the keypad while the field is focused. Mirrors
    /// `TrackerNumberMaxView`: seeded from `value` on focus, parsed back on blur.
    @State private var draft: String
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(
        value: Double,
        unit: String? = nil,
        color: Color = .accent,
        onSave: @escaping (Double) -> Void = { _ in }
    ) {
        self.unit = unit
        self.color = color
        self.onSave = onSave
        _value = State(initialValue: max(value, 0))
        _draft = State(initialValue: value.formatted(.number.grouping(.never)))
    }

    /// The value the confirm button acts on: the live draft while typing, the
    /// committed value otherwise — so "Done" reflects what's on screen before the
    /// keypad has blurred.
    private var effectiveValue: Double {
        guard isFieldFocused else { return value }
        return Double(draft.replacingOccurrences(of: ",", with: ".")) ?? value
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            Spacer(minLength: 0)

            heroNumber

            if let unit {
                Text(unit)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }

            // A quiet affordance for the re-edit case, when the keypad is down and
            // a bare number wouldn't otherwise read as tappable.
            Text("Tap to change")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(isFieldFocused ? 0 : 1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top)
        // Tap anywhere off the field to dismiss the keypad and reveal the hint.
        .contentShape(.rect)
        .onTapGesture { isFieldFocused = false }
        .safeAreaInset(edge: .bottom) { doneButton }
        .onChange(of: isFieldFocused) { _, focused in
            if focused {
                draft = value.formatted(.number.grouping(.never))
            } else {
                commitDraft()
            }
        }
        // Raise the keypad immediately so the figure reads as editable on present.
        .onAppear { isFieldFocused = true }
        // Commit on *any* exit — the Done button, a swipe-to-dismiss, or a tap
        // outside — folding in any still-focused draft first. There's no way to
        // leave the editor and silently lose the edit.
        .onDisappear {
            commitDraft()
            onSave(value)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .trackScreen("ManualTrackerCreationNumberMaxEdit")
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Maximum")
                .font(.headline)
            Spacer()
            Button(action: { dismiss() }) {
                Label("Close", systemImage: "xmark.circle.fill")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.title2)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Value

    /// The big tappable figure. Both the editable field and the formatted display
    /// stay in the view tree so focus can reliably land on the field; visibility
    /// is swapped with opacity and hit-testing rather than by inserting/removing.
    /// Mirrors `TrackerNumberMaxView.heroNumber`, sized down for the sheet.
    private var heroNumber: some View {
        ZStack {
            TextField("", text: $draft)
                .focused($isFieldFocused)
                .keyboardType(.decimalPad)
                .opacity(isFieldFocused ? 1 : 0)

            Text(value.formatted(.number))
                .contentTransition(.numericText(value: value))
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .opacity(isFieldFocused ? 0 : 1)
                .onTapGesture { isFieldFocused = true }
                .allowsHitTesting(!isFieldFocused)
        }
        .multilineTextAlignment(.center)
        .font(.system(size: 64, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.3)
        .frame(maxWidth: .infinity)
        // A single haptic tick whenever the value lands somewhere new.
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Expected maximum")
        .accessibilityValue("\(value.formatted(.number)) \(unit ?? "")")
    }

    private var doneButton: some View {
        // Lower the keypad and close; the actual commit + write-back happens in
        // `onDisappear`, so this shares the exact path as a swipe-to-dismiss.
        Button(action: { dismiss() }) {
            Text("Done")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
        }
        .controlSize(.extraLarge)
        .buttonStyle(.glassProminent)
        .tint(color)
        .disabled(effectiveValue <= 0)
        .padding()
    }

    // MARK: - Commit

    /// Parse the typed value, clamping to a positive number and falling back to the
    /// last good value on garbage input. Mirrors `TrackerNumberMaxView`.
    private func commitDraft() {
        let normalized = draft.replacingOccurrences(of: ",", with: ".")
        if let parsed = Double(normalized), parsed > 0 {
            withAnimation(.snappy(duration: 0.25)) { value = parsed }
        }
        draft = ""
    }
}

#Preview("With unit") {
    @Previewable @State var max = 12000.0
    Color(.systemGroupedBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NumberMaxEditor(value: max, unit: "steps", color: .green) { max = $0 }
        }
}

#Preview("Unitless") {
    Color(.systemGroupedBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NumberMaxEditor(value: 100, color: .accent)
        }
}
