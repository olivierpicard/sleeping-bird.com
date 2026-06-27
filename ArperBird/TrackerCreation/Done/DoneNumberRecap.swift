//
//  DoneNumberRecap.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/06/2026.
//

import SwiftUI

/// The number ("Other") path's reveal recap: a line plus a wrapping row of
/// tappable chips for the tracker's editable facets — its unit, its max, and its
/// cumulative/snapshot behavior. A dumb, reactive view: it renders the facets it's
/// handed and routes every change through an injected closure (`onSelectUnit`,
/// `onEditMax`, `onToggleBehavior`); it never mutates the model itself. The Max
/// chip's editor sheet is local presentation state — the commit still flows out
/// through `onEditMax`.
struct DoneNumberRecap: View {
    /// The upper bound — shown on the Max chip and used to seed its editor.
    let maxValue: Double
    /// Whether the number has a hard upper bound fixed by the metric itself (e.g. a
    /// rating out of 10). When bounded the max isn't the user's to dial, so the Max
    /// chip is hidden entirely.
    var isBounded: Bool = false
    /// Whether readings accumulate (cumulative) or stand alone (snapshot).
    let behavior: MetricBehavior
    /// The unit label, or nil for a unitless tracker — which hides the unit chip.
    let unit: String?
    /// The AI's proposed units, offered in the unit chip's inline menu. The only
    /// choices the reveal exposes — there's no custom entry.
    var units: [String] = []
    let color: Color
    /// Invoked when the user commits a new maximum from the Max chip's editor.
    var onEditMax: (Double) -> Void = { _ in }
    /// Invoked when the behavior chip is tapped — flips cumulative ↔ snapshot.
    var onToggleBehavior: () -> Void = {}
    /// Invoked when the user picks a unit from the unit chip's inline menu.
    var onSelectUnit: (String) -> Void = { _ in }

    /// Whether the Max chip's editor sheet is up. Local presentation only — the
    /// committed value leaves through `onEditMax`.
    @State private var editingMax = false

    private var recap: LocalizedStringKey {
        switch behavior {
        case .cumulative: "Your entries add up through the day"
        case .snapshot: "Your entries are independent of each other"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            DoneRecapText(recap)
            chipRow
        }
        // The Max chip raises this compact editor; committing writes the new bound
        // back through `onEditMax`, and the editor dismisses itself.
        .sheet(isPresented: $editingMax) {
            NumberMaxEditor(
                value: maxValue,
                unit: unit,
                color: color,
                onSave: onEditMax
            )
        }
    }

    /// The row of editable facets, surfaced as tappable chips. A wrapping, centered
    /// row so each chip keeps its natural width: when the three don't fit on one
    /// line they drop onto a second centered line rather than squeezing a chip's
    /// text to wrap mid-word.
    private var chipRow: some View {
        WrappingHStack(alignment: .center, hSpacing: 8, vSpacing: 8) {
            if unit != nil {
                unitChip
            }

            // A bounded number's max is fixed by the metric itself, so there's
            // nothing for the user to dial — drop the chip rather than show a
            // dead one.
            if !isBounded {
                facetChip(
                    glyph: "arrow.up.to.line.compact",
                    label: "Max",
                    value: maxValue.formatted(.number),
                    hint: "Edit the tracker's maximum value"
                ) { editingMax = true }
            }

            facetChip(
                glyph: behavior.glyph,
                label: behavior.title,
                value: nil,
                hint: "Switch between cumulative and snapshot",
                trailing: "arrow.left.arrow.right"
            ) { onToggleBehavior() }
        }
        .padding(.horizontal)
    }

    /// The unit chip, surfaced as a `Menu`: tapping it drops an inline list of the
    /// AI's proposed units, and picking one re-anchors the tracker's unit in place.
    /// There's deliberately no "type your own" entry — the reveal only offers what
    /// the AI modelled, so every choice carries a known max and granularity. The
    /// current unit is checkmarked.
    private var unitChip: some View {
        Menu {
            ForEach(units, id: \.self) { option in
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
                if let unit {
                    Text(unit)
                        .foregroundStyle(.primary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        // Strip the Menu's default styling so its label renders at the same size
        // and tint as the plain-button facet chips beside it.
        .buttonStyle(.plain)
        .accessibilityLabel("Unit")
        .accessibilityHint("Choose the tracker's unit")
    }

    /// A single facet chip: the facet glyph, its label, an optional emphasized
    /// value (e.g. the max), and an optional trailing glyph (e.g. the swap arrow on
    /// the behavior chip).
    private func facetChip(
        glyph: String,
        label: LocalizedStringKey,
        value: String?,
        hint: String,
        trailing: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            DoneChip(color: color) {
                Image(systemName: glyph)
                    .foregroundStyle(color)
                Text(label)
                if let value {
                    Text(value)
                        .foregroundStyle(.primary)
                }
                if let trailing {
                    Image(systemName: trailing)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }
}

// MARK: - Behavior chip presentation

extension MetricBehavior {
    /// The label shown on the reveal's behavior chip.
    var title: LocalizedStringKey {
        switch self {
        case .cumulative: "Cumulative"
        case .snapshot: "Snapshot"
        }
    }

    /// The glyph shown on the reveal's behavior chip: a summation sign for values
    /// that accumulate, a camera for independent snapshot readings.
    var glyph: String {
        switch self {
        case .cumulative: "sum"
        case .snapshot: "camera"
        }
    }
}

#Preview {
    @Previewable @State var max = 12000.0
    @Previewable @State var behavior: MetricBehavior = .cumulative
    @Previewable @State var unit = "steps"
    DoneNumberRecap(
        maxValue: max,
        behavior: behavior,
        unit: unit,
        units: ["steps", "km", "miles"],
        color: .green,
        onEditMax: { max = $0 },
        onToggleBehavior: {
            behavior = behavior == .cumulative ? .snapshot : .cumulative
        },
        onSelectUnit: { unit = $0 }
    )
}
