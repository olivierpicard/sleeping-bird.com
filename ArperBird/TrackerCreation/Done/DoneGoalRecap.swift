//
//  DoneGoalRecap.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The goal path's reveal recap: a line plus a wrapping row of tappable chips for
/// the goal's editable facets — its unit, its daily target, and the step between
/// entries. A dumb, reactive view: it renders the facets it's handed and routes
/// every change through an injected closure (`onSelectUnit`, `onEditGoal`,
/// `onEditGranularity`); it never mutates the model itself.
///
/// It reuses the number path's editor sheets — `NumberMaxEditor` for the target
/// and `NumberGranularityEditor` for the step — so the goal and number reveals
/// dial their figures with the same controls.
struct DoneGoalRecap: View {
    /// The daily target — shown on the Goal chip and used to seed its editor. For a
    /// daily-gauge tracker this doubles as the gauge's upper bound.
    let goalValue: Double
    /// The step between entries — shown on the Step chip and used to seed its
    /// picker.
    let granularity: Double
    /// The selected unit label, e.g. "glasses".
    let unit: String
    /// The AI's proposed units, offered in the unit chip's inline menu.
    var units: [String] = []
    /// The user's own unit, when they typed one instead of taking an AI suggestion.
    /// Appended to the menu (and kept there even after they switch to an AI unit) so
    /// they can pick it — and the target they set for it — back. Nil when no custom
    /// unit was ever made.
    var customUnit: String? = nil
    let color: Color
    /// Invoked when the user picks a unit from the unit chip's inline menu.
    var onSelectUnit: (String) -> Void = { _ in }
    /// Invoked when the user commits a new daily target from the Goal chip's editor.
    var onEditGoal: (Double) -> Void = { _ in }
    /// Invoked when the user picks a new step from the Step chip's picker.
    var onEditGranularity: (Double) -> Void = { _ in }

    /// Whether the Goal chip's editor sheet is up. Local presentation only — the
    /// committed value leaves through `onEditGoal`.
    @State private var editingGoal = false
    /// Whether the Step chip's picker sheet is up. Local presentation only — the
    /// chosen step leaves through `onEditGranularity`.
    @State private var editingGranularity = false

    /// The full menu of units: the AI's suggestions plus the user's custom unit,
    /// when there is one not already among them.
    private var menuUnits: [String] {
        if let customUnit, !units.contains(customUnit) {
            return units + [customUnit]
        }
        return units
    }

    var body: some View {
        VStack(spacing: 12) {
            DoneRecapText("Log your progress toward the daily goal")
            chipRow
        }
        // The Goal chip raises the same keypad editor the number path uses for its
        // max; committing writes the new target back through `onEditGoal`.
        .sheet(isPresented: $editingGoal) {
            NumberMaxEditor(
                value: goalValue,
                unit: unit.isEmpty ? nil : unit,
                color: color,
                onSave: onEditGoal
            )
        }
        // The Step chip raises the number path's preset picker, bounded by the
        // goal; the chosen step writes back through `onEditGranularity`.
        .sheet(isPresented: $editingGranularity) {
            NumberGranularityEditor(
                granularity: granularity,
                aiGranularity: granularity,
                maxValue: goalValue,
                color: color,
                onSelect: onEditGranularity
            )
        }
    }

    /// The row of editable facets, surfaced as tappable chips. A wrapping, centered
    /// row so each chip keeps its natural width and drops onto a second line rather
    /// than squeezing — mirroring the number recap.
    private var chipRow: some View {
        WrappingHStack(alignment: .center, hSpacing: 8, vSpacing: 8) {
            unitChip

            facetChip(
                glyph: "target",
                label: "Goal",
                value: goalValue.formatted(.number),
                hint: "Edit the daily goal"
            ) { editingGoal = true }

            facetChip(
                glyph: "plusminus",
                label: "Step",
                value: granularity.formatted(.number),
                hint: "Edit the step between entries"
            ) { editingGranularity = true }
        }
        .padding(.horizontal)
    }

    /// The unit chip, surfaced as a `Menu`: tapping it drops the AI's proposed
    /// units, and picking one re-anchors the goal in place. Unlike the number path,
    /// the goal flow lets the user type their own unit — so when there's a custom
    /// unit it sits in the menu alongside the suggestions and stays selectable, so
    /// the user can switch back to it (and the target they set for it) after trying
    /// an AI unit. The current unit is checkmarked; re-picking it is a no-op.
    private var unitChip: some View {
        Menu {
            ForEach(menuUnits, id: \.self) { option in
                Button(action: { onSelectUnit(option) }) {
                    if option == unit {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            DoneChip(color: color) {
                Image(systemName: "ruler")
                    .foregroundStyle(color)
                Text("Unit")
                if !unit.isEmpty {
                    Text(unit)
                        .foregroundStyle(.primary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        // Strip the Menu's default styling so its label matches the plain-button
        // facet chips beside it.
        .buttonStyle(.plain)
        .accessibilityLabel("Unit")
        .accessibilityHint("Choose the tracker's unit")
    }

    /// A single facet chip: the facet glyph, its label, and an emphasized value
    /// (the goal or the step). Mirrors the number recap's chip.
    private func facetChip(
        glyph: String,
        label: LocalizedStringKey,
        value: String,
        hint: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            DoneChip(color: color) {
                Image(systemName: glyph)
                    .foregroundStyle(color)
                Text(label)
                Text(value)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }
}

#Preview {
    // Seeded on a custom unit ("cups") so the menu shows it alongside the AI units
    // and keeps offering it after switching away — mirroring the real flow's
    // `goalMenuCustomUnit`.
    @Previewable @State var goal = 6.0
    @Previewable @State var granularity = 1.0
    @Previewable @State var unit = "cups"
    let aiUnits = ["glasses", "ml", "liters"]
    DoneGoalRecap(
        goalValue: goal,
        granularity: granularity,
        unit: unit,
        units: aiUnits,
        customUnit: aiUnits.contains(unit) ? "cups" : unit,
        color: .blue,
        onSelectUnit: { unit = $0 },
        onEditGoal: { goal = $0 },
        onEditGranularity: { granularity = $0 }
    )
}
