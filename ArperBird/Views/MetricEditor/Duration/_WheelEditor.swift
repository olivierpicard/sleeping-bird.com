//
//  _WheelEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 01/05/2026.
//

import SwiftUI

struct _WheelEditor: View {
    let mainColor: Color
    let onAdd: (TimeInterval) -> Void

    @State private var components: [_DurationGranularity: Int]

    private let units: [_DurationGranularity]

    init(
        defaultValue: TimeInterval,
        mainColor: Color,
        onAdd: @escaping (TimeInterval) -> Void
    ) {
        self.mainColor = mainColor
        self.onAdd = onAdd

        let units = _durationUnits()
        self.units = units
        let totalMs = Int((defaultValue * 1000).rounded())
        _components = State(initialValue: _durationComponents(from: totalMs, units: units))
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 0) {
                ForEach(units, id: \.self) { unit in
                    wheel(for: unit)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)

            _SaveButton(mainColor: mainColor) {
                let totalSeconds = TimeInterval(_durationTotalMs(components)) / 1000
                onAdd(totalSeconds)
            }
        }
        .padding(.vertical, 24)
//        .presentationBackground(.windowBackground)
    }

    @ViewBuilder
    private func wheel(for unit: _DurationGranularity) -> some View {
        let upper = _durationUnitMax(unit)
        let binding = Binding<Int>(
            get: { components[unit] ?? 0 },
            set: { components[unit] = $0 }
        )

        HStack(spacing: 4) {
            Picker("", selection: binding) {
                ForEach(0...upper, id: \.self) { value in
                    Text("\(value)")
                        .font(.system(size: 22, weight: .medium))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Text(unit.shortLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
        }
    }
}

#Preview("Sleep") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _WheelEditor(
                defaultValue: 7.5 * 3600,
                mainColor: .indigo,
                onAdd: { _ in }
            )
            .presentationDetents([.height(MetricInputFactory.EditorHeight.duration)])
        }
}

#Preview("Workout") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _WheelEditor(
                defaultValue: 30 * 60,
                mainColor: .orange,
                onAdd: { _ in }
            )
            .presentationDetents([.height(MetricInputFactory.EditorHeight.duration)])
        }
}
