//
//  TrackerGoalUnitListView.swift
//  ArperBird
//
//  Created by Olivier Picard on 24/06/2026.
//

import SwiftUI

/// Page 1 of the goal "Edit" sub-flow: choose the unit. Every AI-suggested unit
/// is shown at once as a tappable row, so nothing hides behind a swipe and there
/// is no dead space to scroll past. The selected row fills with the accent
/// color.
struct TrackerGoalUnitListView: View {
    /// A suggested unit plus the daily goal the AI proposed for it, used to show
    /// a sample value ("e.g. 8 per day") that anchors the unit as a measurement.
    struct UnitOption: Hashable {
        let unit: String
        let dailyGoal: Double
    }

    let name: String
    let options: [UnitOption]
    /// The tracker's raw color; `mainColor` corrects it locally for this
    /// screen's text-bearing controls (selected row fill, "Next" button).
    let color: Color
    var onNext: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedIndex: Int

    private var mainColor: Color { color.readableControlTint(in: colorScheme) }

    init(
        name: String = "Drink more water",
        options: [UnitOption] = [
            .init(unit: "glasses", dailyGoal: 8),
            .init(unit: "ml", dailyGoal: 2000),
            .init(unit: "L", dailyGoal: 2),
        ],
        selectedUnit: String? = nil,
        color: Color,
        onNext: @escaping (String) -> Void = { _ in }
    ) {
        self.name = name
        self.options = options
        self.color = color
        self.onNext = onNext
        // Land on the incoming unit if it matches a suggestion, otherwise the
        // first suggestion.
        if let selectedUnit, let index = options.firstIndex(where: { $0.unit == selectedUnit }) {
            _selectedIndex = State(initialValue: index)
        } else {
            _selectedIndex = State(initialValue: 0)
        }
    }

    /// The unit the highlighted row represents.
    private var selectedUnit: String {
        options.indices.contains(selectedIndex) ? options[selectedIndex].unit : ""
    }

    var body: some View {
        VStack(spacing: 16) {
            header
                .padding(.vertical)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        suggestionRow(for: option, at: index)
                    }
                }
                .padding(.horizontal)
            }

            Button(action: { onNext(selectedUnit) }) {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .tint(mainColor)
            .disabled(selectedUnit.isEmpty)
            .padding()
        }
        .trackScreen("ManualTrackerCreationGoalUnit")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Pick a unit")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header

    /// The question framing, pinned above the list.
    private var header: some View {
        Text("How do you measure “\(name)”?")
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    // MARK: - Rows

    private func suggestionRow(for option: UnitOption, at index: Int) -> some View {
        let isSelected = selectedIndex == index
        let caption: LocalizedStringKey = "e.g. \(option.dailyGoal.formatted(.number)) per day"
        return Button(action: { selectedIndex = index }) {
            rowLayout(isSelected: isSelected) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.unit)
                        .font(.headline)
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Shared card scaffold: a leading radio indicator, the row's content, and a
    /// fill that flips to the accent color when selected.
    private func rowLayout<Content: View>(
        isSelected: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .secondary)

            content()
                .foregroundStyle(isSelected ? .white : .primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? AnyShapeStyle(mainColor) : AnyShapeStyle(.quaternary.opacity(0.5)))
        )
    }
}

#Preview("List") {
    NavigationStack {
        TrackerGoalUnitListView(selectedUnit: "glasses", color: .accent)
    }
}
