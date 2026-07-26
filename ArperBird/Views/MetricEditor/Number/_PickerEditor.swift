//
//  _PickerEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

struct _PickerEditor: View {
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

    private var values: [Double] {
        stride(from: min, through: max, by: step).map { $0 }
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .center, spacing: 12) {
                Picker("", selection: $value) {
                    ForEach(values, id: \.self) { v in
                        Text(_meFormat(v, step: step)).tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 160)

                if let unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal)

            _SaveButton(mainColor: mainColor) { onAdd(value) }
        }
        .padding(.vertical, 24)
        .animation(.snappy, value: value)
    }
}

#Preview {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
    .sheet(isPresented: $isSheetPresented) {
        _PickerEditor(min: 0, max: 200, defaultValue: 8, step: 1, unit: "glasses", mainColor: .blue) { _ in }
             
        .presentationDetents([.height(MetricInputFactory.EditorHeight.picker)])
    }
}
