//
//  TrackerCategoryTypeView.swift
//  ArperBird
//
//  Created by Olivier Picard on 25/06/2026.
//

import SwiftUI

/// The step that follows the editable labels screen on the `choices` path. It
/// asks whether an entry allows exactly one pick (single choice) or several
/// (multiple choice). Each option is a tappable card that previews the user's
/// own labels rendered with the matching control glyph — radios for single,
/// checkboxes for multiple — so the choice reads as a WYSIWYG sample of the
/// picker they'll later tap through, mirroring `TrackerCategoryLabelsView`.
///
/// The initial selection is seeded from the AI's guess (`categoryAllowsMultiple`),
/// so the common case is a one-tap confirmation.
struct TrackerCategoryTypeView: View {
    /// How many of the user's labels to show in each card's preview row. Three
    /// is enough to convey "one filled vs several filled" without crowding.
    private static let previewCount = 3

    let color: Color
    /// The labels the user just confirmed, previewed inside each option card.
    let labels: [String]
    /// Emits the chosen mode (`true` == multiple choice) on "Next".
    var onNext: (Bool) -> Void

    @State private var allowsMultiple: Bool

    init(
        color: Color = .accent,
        labels: [String] = [],
        initialAllowsMultiple: Bool = false,
        onNext: @escaping (Bool) -> Void = { _ in }
    ) {
        self.color = color
        self.labels = labels
        self.onNext = onNext
        _allowsMultiple = State(initialValue: initialAllowsMultiple)
    }

    var body: some View {
        VStack {
            VStack(spacing: 16) {
                optionCard(
                    isMultiple: false,
                    title: "Single choice",
                    subtitle: "One answer per entry"
                )
                optionCard(
                    isMultiple: true,
                    title: "Multiple choice",
                    subtitle: "Any that apply"
                )
            }
            .padding()

            Spacer()

            Button(action: { onNext(allowsMultiple) }) {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .padding()
        }
        .trackScreen("ManualTrackerCreationCategoryType")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("One pick or several?")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func optionCard(
        isMultiple: Bool,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey
    ) -> some View {
        let isSelected = allowsMultiple == isMultiple
        Button(action: { allowsMultiple = isMultiple }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? color : .secondary)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    previewRow(isMultiple: isMultiple, isSelected: isSelected)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary.opacity(isSelected ? 0.6 : 0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// A sample of the picker this mode produces: the first few labels with the
    /// matching glyph. Single choice fills exactly the first row; multiple fills
    /// all but the last, so "several at once" reads at a glance.
    @ViewBuilder
    private func previewRow(isMultiple: Bool, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(labels.prefix(Self.previewCount).enumerated()), id: \.offset) {
                index, label in
                let filled = isMultiple ? index < Self.previewCount - 1 : index == 0
                HStack(spacing: 5) {
                    Image(systemName: glyph(isMultiple: isMultiple, filled: filled))
                        .foregroundStyle(filled && isSelected ? color : .secondary)
                    Text(label)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .font(.footnote)
            }
        }
    }

    private func glyph(isMultiple: Bool, filled: Bool) -> String {
        if isMultiple {
            filled ? "checkmark.square.fill" : "square"
        } else {
            filled ? "largecircle.fill.circle" : "circle"
        }
    }
}

#Preview {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerCategoryTypeView(
                labels: ["Happy", "Calm", "Tired", "Anxious"]
            )
        }
    }
    .presentationDetents([.large])
}
