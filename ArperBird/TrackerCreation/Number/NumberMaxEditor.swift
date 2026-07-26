//
//  NumberMaxEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// A compact bottom-sheet editor for a number tracker's maximum, raised from the
/// reveal's "Max" chip. It drops the `−`/`+` steppers and any question framing:
/// the figure *is* the control — an always-editable keypad field that auto-raises
/// on present so the user can just start typing. Sized to a medium detent so the
/// reveal card stays visible behind it, with a navigation bar carrying an `X` to
/// dismiss and a tinted glass checkmark to save.
struct NumberMaxEditor: View {
    /// The unit label shown beneath the figure, or nil for a unitless tracker.
    let unit: String?
    let color: Color
    /// Commit the edited maximum. The sheet dismisses itself afterwards.
    var onSave: (Double) -> Void

    @State private var value: Double
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(
        value: Double,
        unit: String? = nil,
        color: Color,
        onSave: @escaping (Double) -> Void = { _ in }
    ) {
        self.unit = unit
        self.color = color
        self.onSave = onSave
        _value = State(initialValue: max(value, 0))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer()
                heroNumber
                if let unit {
                    Text(unit)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.top)
            // Raise the keypad immediately so the user can just start typing.
            .onAppear { isFocused = true }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        onSave(value)
                        dismiss()
                    }) {
                        Label("Confirm", systemImage: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(color)
                    .disabled(value <= 0)
                }
            }
        }
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
        .trackScreen("ManualTrackerCreationNumberMaxEdit")
    }

    /// The big editable figure: a single always-focused keypad field bound
    /// straight to `value`, so there's no draft string or manual parsing.
    private var heroNumber: some View {
        TextField("", value: $value, format: .number.grouping(.never))
            .focused($isFocused)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Expected maximum")
            .accessibilityValue("\(value.formatted(.number)) \(unit ?? "")")
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
