//
//  _SliderEditor.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

struct _SliderEditor: View {
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

    var body: some View {
        VStack(spacing: 32) {
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

            Slider(value: $value, in: min...max, step: step)
                .tint(mainColor)
                .padding(.horizontal)

            _SaveButton(mainColor: mainColor) { onAdd(value) }
        }
        .padding(.vertical, 32)
        .animation(.snappy, value: value)
        .sensoryFeedback(.impact(weight: .light), trigger: value)
    }
}

#Preview {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
    .sheet(isPresented: $isSheetPresented) {
        MetricEditor.Number(min: 0, max: 20, defaultValue: 8, step: 1, unit: "glasses", mainColor: .blue)
            .style(.slider)
            .presentationDetents([.height(280)])
    }
}
