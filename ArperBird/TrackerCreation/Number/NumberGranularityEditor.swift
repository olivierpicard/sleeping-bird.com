//
//  NumberGranularityEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 28/06/2026.
//

import SwiftUI

/// A compact bottom-sheet picker for a number tracker's granularity — the step
/// between entries — raised from the reveal's "Step" chip. A sibling to
/// `NumberMaxEditor` in chrome (navigation bar with a dismissing `X`, a medium
/// detent so the reveal card stays visible behind it), but instead of a keypad
/// it offers a wrapping row of preset step tags. Tapping a tag commits straight
/// away and the sheet dismisses itself — there's no separate confirm.
///
/// The presets are filtered to *divisors of the tracker's max* so a chosen step
/// never over- or under-shoots the range. The AI's own suggestion is always
/// offered: if it isn't one of the presets it leads the row, set apart with a
/// touch more padding.
struct NumberGranularityEditor: View {
    /// The currently selected step — the tag rendered as filled/selected.
    let granularity: Double
    /// The AI's suggested step. Always offered, even when it doesn't divide the
    /// max; when it isn't a preset it leads the row, set apart.
    let aiGranularity: Double
    /// The tracker's upper bound. Presets that don't evenly divide it are
    /// dropped so a step always lands on a clean fraction of the range.
    let maxValue: Double
    let color: Color
    /// Commit the chosen step. The sheet dismisses itself afterwards.
    var onSelect: (Double) -> Void

    @Environment(\.dismiss) private var dismiss

    /// The fixed menu of steps offered before filtering.
    private static let presets: [Double] = [0.1, 0.5, 1, 5, 10, 50, 100]

    /// A tag to render: its step value and whether it's the AI's suggestion set
    /// apart at the head of the row.
    private struct Tag: Identifiable {
        let value: Double
        let isAiLead: Bool
        var id: Double { value }
    }

    /// The tags to show: presets that evenly divide the max, with the AI's
    /// suggestion guaranteed a slot — leading the row, set apart, when it isn't
    /// already one of the divisor presets.
    private var tags: [Tag] {
        // Drop any preset that equals the max — a step the size of the whole
        // range isn't a meaningful increment.
        let divisors = Self.presets.filter {
            divides(maxValue, by: $0) && !isSameStep($0, maxValue)
        }
        if divisors.contains(where: { isSameStep($0, aiGranularity) }) {
            return divisors.map { Tag(value: $0, isAiLead: false) }
        }
        return [Tag(value: aiGranularity, isAiLead: true)]
            + divisors.map { Tag(value: $0, isAiLead: false) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                DoneRecapText("Step between entries")
                tagRow
                Spacer()
            }
            .padding()
            .navigationTitle("Granularity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
        .trackScreen("ManualTrackerCreationNumberGranularityEdit")
    }

    /// The wrapping, centered row of step tags. Each commits on tap.
    private var tagRow: some View {
        WrappingHStack(alignment: .center, hSpacing: 8, vSpacing: 8) {
            ForEach(tags) { tag in
                Button(action: {
                    onSelect(tag.value)
                    dismiss()
                }) {
                    tagChip(tag)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tag.value.formatted(.number)))
                .accessibilityAddTraits(
                    isSameStep(tag.value, granularity) ? [.isSelected] : []
                )
            }
        }
    }

    /// A single step tag. The selected step fills with the tracker's color; the
    /// AI lead tag carries a touch more horizontal padding so it reads as set
    /// apart at the head of the row.
    @ViewBuilder
    private func tagChip(_ tag: Tag) -> some View {
        let selected = isSameStep(tag.value, granularity)
        Text(tag.value.formatted(.number))
            .font(.footnote.weight(.medium))
            .foregroundStyle(selected ? Color.white : .secondary)
            .padding(.horizontal, tag.isAiLead ? 18 : 12)
            .padding(.vertical, 6)
            .background {
                Capsule().fill(selected ? AnyShapeStyle(color) : AnyShapeStyle(.quaternary.opacity(0.5)))
            }
            .overlay { Capsule().stroke(color.opacity(0.4), lineWidth: 1) }
    }

    // MARK: - Float-safe step math

    /// Whether `value` is evenly divisible by `step` — a float-safe `value % step
    /// == 0` so e.g. `0.1` cleanly divides `8`.
    private func divides(_ value: Double, by step: Double) -> Bool {
        guard value > 0, step > 0 else { return false }
        let q = value / step
        return (q - q.rounded()).magnitude < 1e-9
    }

    /// Whether two steps are the same, tolerant of float drift.
    private func isSameStep(_ a: Double, _ b: Double) -> Bool {
        (a - b).magnitude < 1e-9
    }
}

#Preview("AI step is a preset") {
    @Previewable @State var step = 1.0
    Color(.systemGroupedBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NumberGranularityEditor(
                granularity: step,
                aiGranularity: 1,
                maxValue: 100,
                color: .green
            ) { step = $0 }
        }
}

#Preview("AI step set apart") {
    @Previewable @State var step = 0.25
    Color(.systemGroupedBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NumberGranularityEditor(
                granularity: step,
                aiGranularity: 0.25,
                maxValue: 8,
                color: .blue
            ) { step = $0 }
        }
}
