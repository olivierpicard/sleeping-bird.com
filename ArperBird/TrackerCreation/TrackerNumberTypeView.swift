//
//  TrackerNumberTypeView.swift
//  ArperBird
//
//  Created by Olivier Picard on 22/06/2026.
//

import SwiftUI

/// Lets the user pick how a number tracker behaves over time — `cumulative`
/// (values that make sense summed) vs `snapshot` (independent readings). Mirrors
/// the `MetricBehavior` contract the AI pipeline produces.
struct TrackerNumberTypeView: View {
    let color: Color
    var onNext: (MetricBehavior) -> Void

    @State private var selection: MetricBehavior

    init(
        color: Color = .accent,
        onNext: @escaping (MetricBehavior) -> Void = { _ in }
    ) {
        self.color = color
        self.onNext = onNext
        _selection = State(initialValue: .cumulative)
    }

    private let options: [Option] = [
        Option(
            behavior: .cumulative,
            emoji: "🪣",
            label: "Adds up over the day",
            examples: "Like steps, water intake, or time spent..."
        ),
        Option(
            behavior: .snapshot,
            emoji: "📸",
            label: "Snapshot",
            examples: "Like weight, temperature, or heart rate..."
        ),
    ]

    var body: some View {
        VStack {
            VStack(spacing: 16) {
                ForEach(options) { option in
                    optionCard(for: option)
                }
            }
            .padding()

            Spacer()

            Button(action: { onNext(selection) }) {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .padding()
        }
        .trackScreen("ManualTrackerCreationNumberType")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("What is the number type ?")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func optionCard(for option: Option) -> some View {
        let isSelected = option.behavior == selection
        Button(action: { selection = option.behavior }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? color : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(option.emoji) \(Text(option.label))")
                        .font(.headline)
                    Text(option.examples)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
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

    private struct Option: Identifiable {
        var id: MetricBehavior { behavior }
        let behavior: MetricBehavior
        let emoji: String
        let label: LocalizedStringKey
        let examples: LocalizedStringKey
    }
}

#Preview {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerNumberTypeView()
        }
    }
    .presentationDetents([.large])
}
