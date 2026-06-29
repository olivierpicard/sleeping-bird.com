//
//  DurationMaxEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 29/06/2026.
//

import SwiftUI

struct DurationMaxEditor: View {
    let color: Color
    let onSave: (Int) -> Void

    @State private var components: [_DurationGranularity: Int]

    private let units: [_DurationGranularity] = _durationUnits(granularity: .s, maxInSeconds: 99 * 3600)

    init(maxSeconds: Int, color: Color, onSave: @escaping (Int) -> Void) {
        self.color = color
        self.onSave = onSave
        let units = _durationUnits(granularity: .s, maxInSeconds: 99 * 3600)
        _components = State(initialValue: _durationComponents(from: maxSeconds * 1000, units: units))
    }

    private var totalSeconds: Int {
        _durationTotalMs(components) / 1000
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 0) {
                ForEach(Array(units.enumerated()), id: \.element) { index, unit in
                    wheel(for: unit, isTop: index == 0)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)

            _SaveButton(mainColor: color, isEnabled: totalSeconds > 0) {
                onSave(totalSeconds)
            }
        }
        .padding(.vertical, 24)
        .presentationDetents([.height(320)])
    }

    @ViewBuilder
    private func wheel(for unit: _DurationGranularity, isTop: Bool) -> some View {
        let upper = _durationUnitMax(unit, maxInSeconds: 99 * 3600, isTop: isTop)
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

#Preview {
    @Previewable @State var isPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isPresented) {
            DurationMaxEditor(maxSeconds: 90 * 60, color: .teal) { _ in }
        }
}
