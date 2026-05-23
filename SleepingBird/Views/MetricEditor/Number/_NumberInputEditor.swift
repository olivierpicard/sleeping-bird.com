//
//  _NumberInputEditor.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

struct _NumberInputEditor: View {
    let min: Double
    let max: Double
    let step: Double
    let unit: String?
    let mainColor: Color
    let onAdd: (Double) -> Void

    @State private var text: String
    @State private var fieldColor: Color = .primary
    @FocusState private var isFocused: Bool

    init(
        min: Double,
        max: Double,
        defaultValue: Double,
        step: Double,
        unit: String?,
        mainColor: Color,
        onAdd: @escaping (Double) -> Void
    ) {
        self.min = min
        self.max = max
        self.step = step
        self.unit = unit
        self.mainColor = mainColor
        self.onAdd = onAdd
        _text = State(initialValue: "")
    }

    private var parsedValue: Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        guard let v = parsedValue else { return false }
        return v >= min && v <= max
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField(String(localized: "number_input_editor.placeholder"), text: $text)
                        .font(.system(size: 64, weight: .light))
                            .keyboardType(
                                step < 1 || min < 0
                                    ? .numbersAndPunctuation : .numberPad
                            )
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .fixedSize()
                        .foregroundStyle(fieldColor)
                        .onChange(of: text) { _, _ in
                            fieldColor = text.isEmpty || isValid ? .primary : .red
                        }
                        
                    if let unit {
                        Text(unit)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("number_input_editor.range \(_meFormat(min, step: step)) \(_meFormat(max, step: step))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)

            _SaveButton(mainColor: mainColor, isEnabled: isValid) {
                guard let v = parsedValue, isValid else { return }
                isFocused = false
                onAdd(v)
            }
        }
        .padding(.vertical, 32)
        .animation(.snappy, value: isValid)
        .sensoryFeedback(.warning, trigger: isValid) { old, new in old && !new }
        .onAppear { isFocused = true }
        .presentationDetents([.height(280)])
    }
}

#Preview {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _NumberInputEditor(
                min: 0,
                max: 200,
                defaultValue: 8,
                step: 1,
                unit: "glasses",
                mainColor: .blue
            ) { _ in }

        }
}
