//
//  StepperView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

struct StepperView: View {
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

    private var canDecrement: Bool { value - step >= min }
    private var canIncrement: Bool { value + step <= max }

    private var formattedValue: String {
        step >= 1 ? String(Int(value)) : String(format: "%.1f", value)
    }

    var body: some View {
        VStack(spacing: 32) {
            HStack(spacing: 24) {
                stepButton(systemName: "minus", enabled: canDecrement) {
                    value = Swift.max(min, value - step)
                }

                VStack(spacing: 4) {
                    Text(formattedValue)
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
        .padding(.vertical, 32)
        .animation(.snappy, value: value)
    }

    private func stepButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(enabled ? mainColor : .secondary)
                .frame(width: 64, height: 64)
                .background {
                    Circle()
                        .fill(mainColor.opacity(0.12))
                }
                .overlay {
                    Circle()
                        .strokeBorder(mainColor.opacity(0.4), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

#Preview {
    @Previewable @State var isSheetPresented = true
    NavigationStack {
        Text("")
    }
    .sheet(isPresented: $isSheetPresented) {
        StepperView(
            min: 0,
            max: 20,
            defaultValue: 8,
            step: 1,
            unit: "glasses",
            mainColor: .blue,
            onAdd: { _ in }
        )
        .presentationDetents([.height(250)]) 
    }
}
