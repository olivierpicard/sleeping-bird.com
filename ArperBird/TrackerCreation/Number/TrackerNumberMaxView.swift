//
//  TrackerNumberMaxView.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/06/2026.
//

import SwiftUI

/// Second step of the `number` ("Other") path: set the realistic upper bound the
/// tracker should expect, in the unit chosen on `TrackerNumberUnitListView`. The
/// AI-suggested value is pre-filled as a big hero number; `−`/`+` nudge it by a
/// magnitude-aware step, and tapping the number itself raises a numeric keypad
/// for an exact value. Mirrors `TrackerGoalValueView`, but frames the bound as
/// "the most you'd log" and drops the goal's "per day" cadence — an open-ended
/// number isn't necessarily a daily total.
struct TrackerNumberMaxView: View {
    let name: String
    let unit: String
    /// The max the AI proposed for this unit (or a neutral default for a custom
    /// unit). Seeds the field and anchors the stepper increment so small counts
    /// step by 1 and large ones by 100.
    let suggestedMax: Double
    let color: Color
    var onNext: (Double) -> Void

    @State private var value: Double
    @State private var draft: String
    @FocusState private var isFieldFocused: Bool

    init(
        name: String = "Body weight",
        unit: String = "kg",
        suggestedMax: Double = 120,
        color: Color = .accent,
        onNext: @escaping (Double) -> Void = { _ in }
    ) {
        self.name = name
        self.unit = unit
        self.suggestedMax = suggestedMax
        self.color = color
        self.onNext = onNext
        _value = State(initialValue: max(suggestedMax, 0))
        _draft = State(initialValue: "")
    }

    /// Step size scaled to the bound's magnitude, mirroring `TrackerGoalValueView`:
    /// 100 for thousands, 10 for hundreds, 1 for whole counts, 0.5 when fractional.
    private var step: Double {
        if suggestedMax >= 1000 { return 100 }
        if suggestedMax >= 100 { return 10 }
        if suggestedMax >= 10 { return 1 }
        if suggestedMax.truncatingRemainder(dividingBy: 1) != 0 { return 0.5 }
        return 1
    }

    var body: some View {
        VStack(spacing: 16) {
            header
                .padding(.top, 40)
                .padding(.bottom, 30)

            valueDisplay

            Spacer()

            Button(action: { onNext(value) }) {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .disabled(value <= 0)
            .padding()
        }
        // Tap anywhere off the field — the background, the header, the unit
        // caption — to dismiss the keypad.
        .contentShape(.rect)
        .onTapGesture { isFieldFocused = false }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isFieldFocused = false }
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: isFieldFocused) { _, focused in
            if focused {
                // Enter the field with the current value as a starting point.
                draft = value.formatted(.number.grouping(.never))
            } else {
                commitDraft()
            }
        }
        .trackScreen("ManualTrackerCreationNumberMax")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Set the range")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header

    /// The question framing, pinned above the value.
    private var header: some View {
        Text("What's the most “\(name)” you'd usually log?")
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            // Keep the full wrapped height when the keyboard shrinks the safe
            // area, rather than collapsing to a single truncated line.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal)
    }

    // MARK: - Value

    /// The hero number flanked by `−`/`+` steppers, with the unit beneath it.
    /// Tapping the number raises a keypad for an exact value.
    private var valueDisplay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                stepperButton(systemImage: "minus", enabled: value - step > 0) {
                    decrement()
                }

                heroNumber

                stepperButton(systemImage: "plus", enabled: true) {
                    increment()
                }
            }

            Text(unit)
                .font(.headline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        // A single haptic tick whenever the value lands somewhere new — from a
        // stepper, the keypad, or VoiceOver — so adjustments feel tactile.
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Expected maximum")
        .accessibilityValue("\(value.formatted(.number)) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: increment()
            case .decrement: decrement()
            default: break
            }
        }
    }

    /// The big tappable figure. Both the editable field and the formatted display
    /// stay in the view tree so focus can reliably land on the field; visibility
    /// is swapped with opacity and hit-testing rather than by inserting/removing.
    private var heroNumber: some View {
        ZStack {
            TextField("", text: $draft)
                .focused($isFieldFocused)
                .keyboardType(.decimalPad)
                .opacity(isFieldFocused ? 1 : 0)

            Text(value.formatted(.number))
                // Roll the digits when the value changes for a polished feel.
                .contentTransition(.numericText(value: value))
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .opacity(isFieldFocused ? 0 : 1)
                .onTapGesture { isFieldFocused = true }
                .allowsHitTesting(!isFieldFocused)
        }
        .multilineTextAlignment(.center)
        // A hero figure genuinely needs to read larger than .largeTitle;
        // rounded matches the playful tone of the rest of the flow.
        .font(.system(size: 72, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(color)
        // Stay on a single line: the figure shrinks to fit the space between the
        // steppers as it grows, rather than wrapping.
        .lineLimit(1)
        .minimumScaleFactor(0.3)
        .frame(maxWidth: .infinity)
    }

    private func increment() {
        withAnimation(.snappy(duration: 0.25)) { value += step }
    }

    private func decrement() {
        withAnimation(.snappy(duration: 0.25)) { value = max(step, value - step) }
    }

    private func stepperButton(
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(systemImage == "plus" ? "Increase" : "Decrease", systemImage: systemImage)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(color)
        .disabled(!enabled)
    }

    /// Parse the typed value when the keypad dismisses, clamping to a positive
    /// number and falling back to the last good value on garbage input.
    private func commitDraft() {
        let normalized = draft.replacingOccurrences(of: ",", with: ".")
        if let parsed = Double(normalized), parsed > 0 {
            withAnimation(.snappy(duration: 0.25)) { value = parsed }
        }
        draft = ""
    }
}

#Preview("Snapshot") {
    NavigationStack {
        TrackerNumberMaxView(name: "Body weight", unit: "kg", suggestedMax: 120, color: .accent)
    }
}

#Preview("Large count") {
    NavigationStack {
        TrackerNumberMaxView(name: "Daily revenue", unit: "$", suggestedMax: 5000, color: .blue)
    }
}
