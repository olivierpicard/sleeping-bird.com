//
//  _WheelEditor.swift
//  SleepingBird
//
//  Created by Olivier Picard on 01/05/2026.
//

import SwiftUI

struct _WheelEditor: View {
    let granularity: _DurationGranularity
    let maxInSeconds: Int
    let mainColor: Color
    let onAdd: (TimeInterval) -> Void

    @State private var components: [_DurationGranularity: Int]

    private let units: [_DurationGranularity]

    init(
        granularity: _DurationGranularity,
        maxInSeconds: Int,
        defaultValue: TimeInterval,
        mainColor: Color,
        onAdd: @escaping (TimeInterval) -> Void
    ) {
        self.granularity = granularity
        self.maxInSeconds = maxInSeconds
        self.mainColor = mainColor
        self.onAdd = onAdd

        let units = _durationUnits(granularity: granularity, maxInSeconds: maxInSeconds)
        self.units = units
        let totalMs = Int((defaultValue * 1000).rounded())
        _components = State(initialValue: _durationComponents(from: totalMs, units: units))
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

            _SaveButton(mainColor: mainColor) {
                let totalSeconds = TimeInterval(_durationTotalMs(components)) / 1000
                onAdd(totalSeconds)
            }
        }
        .padding(.vertical, 24)
//        .presentationBackground(.windowBackground)
        .presentationDetents([.height(320)])
    }

    @ViewBuilder
    private func wheel(for unit: _DurationGranularity, isTop: Bool) -> some View {
        let upper = _durationUnitMax(unit, maxInSeconds: maxInSeconds, isTop: isTop)
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

#Preview("Sleep (h, m)") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _WheelEditor(
                granularity: .m,
                maxInSeconds: 12 * 3600,
                defaultValue: 7.5 * 3600,
                mainColor: .indigo,
                onAdd: { _ in }
            )
        }
}

#Preview("Workout (m, s)") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _WheelEditor(
                granularity: .s,
                maxInSeconds: 90 * 60,
                defaultValue: 30 * 60,
                mainColor: .orange,
                onAdd: { _ in }
            )
        }
}

#Preview("Reaction (s, ms)") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _WheelEditor(
                granularity: .ms,
                maxInSeconds: 5,
                defaultValue: 0.42,
                mainColor: .pink,
                onAdd: { _ in }
            )
        }
}
