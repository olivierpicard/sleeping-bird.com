//
//  PickerView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

struct PickerView: View {
    let min: Double
    let max: Double
    let step: Double
    let unit: String?
    let mainColor: Color
    let onAdd: (Double) -> Void

    @State private var value: Double

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
        _value = State(initialValue: defaultValue)
    }

    private var values: [Double] {
        stride(from: min, through: max, by: step).map { $0 }
    }

    private func format(_ v: Double) -> String {
        step >= 1 ? String(Int(v)) : String(format: "%.1f", v)
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .center, spacing: 12) {
                Picker("", selection: $value) {
                    ForEach(values, id: \.self) { v in
                        Text(format(v))
//                            .font(.system(size: 48, weight: .light))
                            .tag(v)
                        
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

            Button {
                onAdd(value)
            } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(mainColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: mainColor.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
        .animation(.snappy, value: value)
    }
}

#Preview {
    @Previewable @State var isSheetPresented = true
    NavigationStack {
        Text("")
    }
    .sheet(isPresented: $isSheetPresented) {
        PickerView(
            min: 0,
            max: 200,
            defaultValue: 8,
            step: 1,
            unit: "glasses",
            mainColor: .blue,
            onAdd: { _ in }
        )
        .presentationDetents([.height(320)])
    }
}
