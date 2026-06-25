//
//  TrackerDurationConfigView.swift
//  ArperBird
//
//  Created by Olivier Picard on 25/06/2026.
//

import SwiftUI

/// Final step of the `duration` path: confirm the upper bound the tracker's
/// wheel will offer. The AI-suggested max seeds three inline `h`/`m`/`s` wheels —
/// the hero of the screen — so "the text *is* the picker": spin any column to set
/// the value, no sheet. Reuses the `_DurationHelpers` that back `_WheelEditor`
/// (component split / recombine, per-unit bounds) so this page and the manual
/// data-entry editor stay in lockstep.
struct TrackerDurationConfigView: View {
    let name: String
    /// The AI-proposed upper bound, in seconds. Seeds the wheels' starting
    /// positions; the user can dial it anywhere from here.
    let suggestedMaxSeconds: Int
    let color: Color
    var onNext: (Int) -> Void

    /// Live `h`/`m`/`s` values, keyed by unit. Seeded once from the suggestion and
    /// mutated in place by the wheels.
    @State private var components: [_DurationGranularity: Int]

    /// Fixed hours/minutes/seconds columns — the "XX h YY m ZZ s" hero this flow
    /// asks for. (The AI bound is integer seconds, so there's no sub-second unit
    /// to show.)
    private let units: [_DurationGranularity] = [.h, .m, .s]

    init(
        name: String = "Workout",
        suggestedMaxSeconds: Int = 30 * 60,
        color: Color = .accent,
        onNext: @escaping (Int) -> Void = { _ in }
    ) {
        self.name = name
        self.suggestedMaxSeconds = suggestedMaxSeconds
        self.color = color
        self.onNext = onNext
        let totalMs = max(0, suggestedMaxSeconds) * 1000
        _components = State(initialValue: _durationComponents(from: totalMs, units: [.h, .m, .s]))
    }

    /// The dialled-in duration, recombined from the wheels.
    private var totalSeconds: Int {
        _durationTotalMs(components) / 1000
    }

    var body: some View {
        VStack(spacing: 16) {
            header
                .padding(.top, 40)
                .padding(.bottom, 30)

            wheels

            Spacer()

            Button(action: { onNext(totalSeconds) }) {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .disabled(totalSeconds <= 0)
            .padding()
        }
        .trackScreen("ManualTrackerCreationDurationConfig")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Set the duration")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header

    /// The question framing, pinned above the wheels, matching the goal pages.
    private var header: some View {
        Text("What's the longest “\(name)” usually lasts?")
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            // Keep the full wrapped height rather than collapsing to a truncated
            // single line on smaller screens.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal)
    }

    // MARK: - Wheels

    /// The three inline wheels, side by side, with each unit's short label acting
    /// as the separator between columns.
    private var wheels: some View {
        HStack(spacing: 0) {
            ForEach(Array(units.enumerated()), id: \.element) { index, unit in
                wheel(for: unit, isTop: index == 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        // A single haptic tick whenever the dialled value lands somewhere new, so
        // spinning feels tactile — mirroring the goal value screen.
        .sensoryFeedback(.selection, trigger: totalSeconds)
    }

    /// One wheel column. Mirrors `_WheelEditor.wheel(for:)` — same bounds helper
    /// and label placement — but with a larger rounded figure so the picker reads
    /// as the screen's hero rather than a sheet control.
    @ViewBuilder
    private func wheel(for unit: _DurationGranularity, isTop: Bool) -> some View {
        // Generous fixed ceiling (99 h) so the user can raise the max well past
        // the suggestion, rather than being pinned at the seed.
        let upper = _durationUnitMax(unit, maxInSeconds: 99 * 3600, isTop: isTop)
        let binding = Binding<Int>(
            get: { components[unit] ?? 0 },
            set: { components[unit] = $0 }
        )

        HStack(spacing: 4) {
            Picker("", selection: binding) {
                ForEach(0...upper, id: \.self) { value in
                    Text("\(value)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(unit.shortLabel)

            Text(unit.shortLabel)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
        }
    }
}

#Preview("Workout (m, s)") {
    NavigationStack {
        TrackerDurationConfigView(name: "Workout", suggestedMaxSeconds: 30 * 60, color: .orange)
    }
}

#Preview("Sleep (h, m)") {
    NavigationStack {
        TrackerDurationConfigView(name: "Sleep", suggestedMaxSeconds: 8 * 3600, color: .indigo)
    }
}
