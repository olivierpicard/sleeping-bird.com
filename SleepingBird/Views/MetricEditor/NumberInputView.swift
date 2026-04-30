//
//  NumberInputView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

struct NumberInputView: View {
    let min: Double
    let max: Double
    let step: Double
    let unit: String?
    let mainColor: Color
    let onAdd: (Double) -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(
        min: Double,
        max: Double,
        defaultValue: Double,
        step: Double,
        unit: String? = nil,
        mainColor: Color = .accentColor,
        onAdd: @escaping (Double) -> Void = { _ in }
    ) {
        self.min = min
        self.max = max
        self.step = step
        self.unit = unit
        self.mainColor = mainColor
        self.onAdd = onAdd
        let initial = step >= 1 ? String(Int(defaultValue)) : String(format: "%.1f", defaultValue)
        _text = State(initialValue: initial)
    }

    private var allowsNegative: Bool { min < 0 }
    private var allowsDecimal: Bool { step < 1 }

    private var keyboardType: UIKeyboardType {
        if allowsDecimal || allowsNegative {
            return .numbersAndPunctuation
        }
        return .numberPad
    }

    private var parsedValue: Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(normalized) else { return nil }
        return v
    }

    private var isValid: Bool {
        guard let v = parsedValue else { return false }
        return v >= min && v <= max
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("0", text: $text)
                        .font(.system(size: 64, weight: .light))
                        .keyboardType(keyboardType)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .fixedSize()
                        .foregroundStyle(isValid ? Color.primary : Color.red)

                    if let unit {
                        Text(unit)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Range: \(format(min)) – \(format(max))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)

            Button {
                if let v = parsedValue, isValid {
                    isFocused = false
                    onAdd(v)
                }
            } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValid ? mainColor : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: (isValid ? mainColor : .gray).opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
        .animation(.snappy, value: isValid)
        .onAppear { isFocused = true }
    }

    private func format(_ v: Double) -> String {
        step >= 1 ? String(Int(v)) : String(format: "%.1f", v)
    }
}

#Preview {
    @Previewable @State var isSheetPresented = true
    NavigationStack {
        Text("")
    }
    .sheet(isPresented: $isSheetPresented) {
        NumberInputView(
            min: 0,
            max: 200,
            defaultValue: 8,
            step: 1,
            unit: "glasses",
            mainColor: .blue,
            onAdd: { _ in }
        )
        .presentationDetents([.height(280)])
    }
}
