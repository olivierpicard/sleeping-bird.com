//
//  _StepperEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

struct _StepperEditor: View {
    let min: Double
    let max: Double
    let step: Double
    let unit: String?
    let mainColor: Color
    let onAdd: (Double) -> Void

    @State private var value: Double

    init(min: Double, max: Double, defaultValue: Double, step: Double, unit: String?, mainColor: Color, onAdd: @escaping (Double) -> Void) {
        self.min = min
        self.max = max
        self.step = step
        self.unit = unit
        self.mainColor = mainColor
        self.onAdd = onAdd
        _value = State(initialValue: defaultValue)
    }

    private var canDecrement: Bool { value - step >= min }
    private var canIncrement: Bool { value + step <= max }

    var body: some View {
        VStack(spacing: 32) {
            HStack(spacing: 24) {
                stepButton(systemName: "minus", enabled: canDecrement) {
                    value = Swift.max(min, value - step)
                }

                VStack(spacing: 4) {
                    Text(_meFormat(value, step: step))
                        .font(.system(size: 64, weight: .light))
                        .contentTransition(.numericText(value: value))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let unit {
                        Text(unit)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity)

                stepButton(systemName: "plus", enabled: canIncrement) {
                    value = Swift.min(max, value + step)
                }
            }
            .padding(.horizontal)

            _SaveButton(mainColor: mainColor) { onAdd(value) }
        }
        .padding(.vertical, 32)
        .animation(.snappy, value: value)
        .sensoryFeedback(.impact(weight: .light), trigger: value)
        .presentationDetents([.height(250)])
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(enabled ? mainColor : .secondary)
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .contentShape(.circle)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

#Preview {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
    .sheet(isPresented: $isSheetPresented) {
        _StepperEditor(min: 0, max: 20, defaultValue: 8, step: 1, unit: "glasses", mainColor: .blue) { _ in }
    }
}

