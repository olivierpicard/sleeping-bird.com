//
//  TrackerNumberUnitListView.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/06/2026.
//

import SwiftUI

/// First step after loading on the `number` ("Other") path: choose the unit.
/// Every AI-suggested unit is shown at once as a tappable row, so nothing hides
/// behind a swipe; a trailing "Type my own" row reveals an inline field. Mirrors
/// `TrackerGoalUnitListView`, but anchors each unit with its typical max ("e.g.
/// up to 120") rather than a daily goal — and a custom unit routes the flow
/// through the number-type screen, since the AI never modelled its behavior.
struct TrackerNumberUnitListView: View {
    /// A suggested unit plus the realistic max the AI proposed for it, used to
    /// show a sample value ("e.g. up to 120") that anchors the unit as a measure.
    struct UnitOption: Hashable {
        let unit: String
        let typicalMax: Double
    }

    let name: String
    let options: [UnitOption]
    let color: Color
    var onNext: (String) -> Void

    @State private var selection: Page
    @State private var customUnit: String
    @FocusState private var isCustomFocused: Bool

    /// Which row is highlighted: one of the suggestions (by index) or the
    /// trailing custom-entry row.
    private enum Page: Hashable {
        case suggested(Int)
        case custom
    }

    init(
        name: String = "Body weight",
        options: [UnitOption] = [
            .init(unit: "kg", typicalMax: 120),
            .init(unit: "lb", typicalMax: 260),
        ],
        selectedUnit: String? = nil,
        color: Color = .accent,
        onNext: @escaping (String) -> Void = { _ in }
    ) {
        self.name = name
        self.options = options
        self.color = color
        self.onNext = onNext
        // Land on the incoming unit: a matching suggestion if there is one,
        // otherwise seed the custom row with it.
        if let selectedUnit, let index = options.firstIndex(where: { $0.unit == selectedUnit }) {
            _selection = State(initialValue: .suggested(index))
            _customUnit = State(initialValue: "")
        } else if let selectedUnit, !selectedUnit.isEmpty {
            _selection = State(initialValue: .custom)
            _customUnit = State(initialValue: selectedUnit)
        } else {
            _selection = State(initialValue: options.isEmpty ? .custom : .suggested(0))
            _customUnit = State(initialValue: "")
        }
    }

    /// The unit the highlighted row represents, trimmed for the custom case.
    private var selectedUnit: String {
        switch selection {
        case .suggested(let index):
            options.indices.contains(index) ? options[index].unit : ""
        case .custom:
            customUnit.trimmingCharacters(in: .whitespaces)
        }
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
                    customRow
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
            .disabled(selectedUnit.isEmpty)
            .padding()
        }
        .onChange(of: selection) { _, newValue in
            isCustomFocused = newValue == .custom
        }
        .trackScreen("ManualTrackerCreationNumberUnit")
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
        let isSelected = selection == .suggested(index)
        let caption = "e.g. up to \(option.typicalMax.formatted(.number))"
        return Button(action: { selection = .suggested(index) }) {
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

    private var customRow: some View {
        let isSelected = selection == .custom
        return Button(action: { selection = .custom }) {
            rowLayout(isSelected: isSelected) {
                if isSelected {
                    TextField("Type my own…", text: $customUnit)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .tint(.white)
                        .focused($isCustomFocused)
                        .submitLabel(.done)
                } else {
                    let trimmed = customUnit.trimmingCharacters(in: .whitespaces)
                    Text(trimmed.isEmpty ? "Type my own…" : trimmed)
                        .font(.headline)
                        .foregroundStyle(trimmed.isEmpty ? .secondary : .primary)
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
                .fill(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(.quaternary.opacity(0.5)))
        )
    }
}

#Preview("List") {
    NavigationStack {
        TrackerNumberUnitListView(selectedUnit: "kg", color: .accent)
    }
}
