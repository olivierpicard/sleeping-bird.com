//
//  TrackerFormatPickerView.swift
//  ArperBird
//
//  Created by Olivier Picard on 12/07/2026.
//

import SwiftUI

/// Once a suggestion chip has already resolved a name/emoji/color — a
/// dashboard badge tap — this screen asks *how* to view it: one big preview
/// card plus a row of format chips below, with no text field or example
/// chips competing for attention. Wired into `TrackerCreationFlow` as the
/// entry point for a seeded (badge) creation, replacing `TrackerIntentView`
/// since the intent is already known.
struct TrackerFormatPickerView: View {
    /// One way this tracker can be logged — mirrors `TrackerIntentView`'s
    /// private `IntentFormat`. Built via `FormatOption.make(for:name:emoji:color:)`.
    struct FormatOption: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let kind: TrackerKind
        let metric: Metric
    }

    let name: String
    let emoji: String
    let color: Color
    let formats: [FormatOption]

    /// Hands the chosen format's kind off to `TrackerCreationFlow`, which
    /// routes into that kind's step machinery — mirrors `TrackerIntentView`'s
    /// `onContinue`. A no-op default lets the screen preview standalone.
    var onContinue: (TrackerKind) -> Void = { _ in }

    @State private var selectedIndex = 0
    @Environment(\.colorScheme) private var colorScheme

    /// The resolved suggestion's color, passed through the readability
    /// filter so the card, its chart, and the chips all share the same
    /// corrected shade — mirrors `TrackerIntentView.mainColor`.
    private var mainColor: Color {
        color.readableControlTint(in: colorScheme)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            MetricView(
                mainColor: .gray,
                header: {
                    MetricHeaderTextView(
                        title: name,
                        emoji: emoji,
                        mainColor: .gray
                    )
                },
                // Preview card stays neutral gray, independent of the
                // tracker's resolved color — only the format chips below use it.
                chart: MiniChartFactory.make(
                    from: formats[selectedIndex].metric,
                    colorOverride: .gray
                )
            )
            .animation(.snappy, value: selectedIndex)

            HStack(spacing: 8) {
                ForEach(formats.indices, id: \.self) { index in
                    FormatChip(
                        format: formats[index],
                        isSelected: index == selectedIndex,
                        color: .accentColor
                    ) {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedIndex = index
                        }
                    }
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 24)
        .safeAreaInset(edge: .bottom) {
            Button(action: { onContinue(formats[selectedIndex].kind) }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .padding()
        }
        // No own cancel button: this screen is a pushed step inside
        // `TrackerCreationFlow`'s `NavigationStack`, which already supplies
        // the xmark cancellation action for the whole stack.
        .navigationTitle(String(localized: "How to track it"))
        .navigationSubtitle("How should \"\(name)\" look?")
        .navigationBarTitleDisplayMode(.large)
    }
}

/// A single format option, styled to read as tappable: the selected chip
/// fills solid with a checkmark, unselected chips get a visible outline (not
/// just muted text), and the press-down scale gives tactile feedback.
private struct FormatChip: View {
    let format: TrackerFormatPickerView.FormatOption
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(format.label)
            } icon: {
                Image(systemName: isSelected ? "checkmark" : format.icon)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isSelected ? color : Color(.tertiarySystemFill))
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? .clear : Color.secondary.opacity(0.35),
                    lineWidth: 1
                )
            )
            .shadow(
                color: isSelected ? color.opacity(0.35) : .clear,
                radius: 6,
                y: 2
            )
        }
        .buttonStyle(ChipPressStyle())
    }
}

/// Scales the chip down slightly on press for tactile feedback — `.plain`
/// gives none of its own.
private struct ChipPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Previews

extension TrackerFormatPickerView.FormatOption {
    /// Builds the pill + preview card for one logging format — mirrors
    /// `TrackerIntentView`'s private `intentFormat(for:name:emoji:color:)` so
    /// both screens render the same fake preview for a given format type.
    /// Shared by the real `TrackerCreationFlow` wiring (a badge tap's
    /// `TrackerSuggestion.formats`) and this file's previews.
    static func make(
        for type: IntentFormatType,
        name: String,
        emoji: String,
        color: Color
    ) -> Self {
        switch type {
        case .duration:
            let schema = MetricSchema.Fake.duration(
                title: name,
                emoji: emoji,
                chart: .bar
            )
            return .init(
                label: String(localized: "Time spent"),
                icon: "clock",
                kind: .duration,
                metric: Metric(
                    from: schema,
                    color: color,
                    data: Metric.fakeData(for: schema.config, days: 40)
                )
            )
        case .binary:
            let schema = MetricSchema.Fake.binary(
                title: name,
                emoji: emoji,
                chart: .calendar
            )
            return .init(
                label: String(localized: "Yes / No"),
                icon: "checkmark.circle",
                kind: .binary,
                metric: Metric(
                    from: schema,
                    color: color,
                    data: Metric.fakeData(for: schema.config)
                )
            )
        case .number:
            let schema = MetricSchema.Fake.number(
                title: name,
                emoji: emoji,
                goal: nil,
                chart: .bar
            )
            return .init(
                label: String(localized: "A number"),
                icon: "number",
                kind: .number,
                metric: Metric(
                    from: schema,
                    color: color,
                    data: Metric.fakeData(for: schema.config, days: 40)
                )
            )
        case .goal:
            let schema = MetricSchema.Fake.number(
                title: name,
                emoji: emoji,
                min: 0,
                max: 10,
                granularity: 1,
                goal: 8,
                chart: .dailyGauge
            )
            return .init(
                label: String(localized: "Daily goal"),
                icon: "target",
                kind: .goal,
                metric: Metric(
                    from: schema,
                    color: color,
                    data: Metric.fakeData(for: schema.config)
                )
            )
        case .choices:
            let schema = MetricSchema.Fake.categorySingle(
                title: name,
                emoji: emoji,
                chart: .pie
            )
            return .init(
                label: String(localized: "Pick from a list"),
                icon: "list.bullet",
                kind: .choices,
                metric: Metric(
                    from: schema,
                    color: color,
                    data: Metric.fakeData(for: schema.config)
                )
            )
        case .date:
            let schema = MetricSchema.Fake.datetime(
                title: name,
                emoji: emoji,
                chart: .calendar
            )
            return .init(
                label: String(localized: "A date"),
                icon: "calendar",
                kind: .date,
                metric: Metric(
                    from: schema,
                    color: color,
                    data: Metric.fakeData(for: schema.config)
                )
            )
        }
    }
}

#Preview("Water — goal + number") {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerFormatPickerView(
                name: "Glasses of Water",
                emoji: "💧",
                color: .orange,
                formats: [
                    .make(for: .goal, name: "Glasses of Water", emoji: "💧", color: .orange),
                    .make(for: .number, name: "Glasses of Water", emoji: "💧", color: .orange),
                ]
            )
        }
        .environment(\.locale, Locale(identifier: "en_US"))
    }
    .presentationDetents([.large])
}

#Preview("Reading — duration + number") {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerFormatPickerView(
                name: "Time Reading",
                emoji: "📖",
                color: .purple,
                formats: [
                    .make(for: .duration, name: "Time Reading", emoji: "📖", color: .purple),
                    .make(for: .number, name: "Time Reading", emoji: "📖", color: .purple),
                ]
            )
        }
        .environment(\.locale, Locale(identifier: "en_US"))
    }
    .presentationDetents([.large])
}
