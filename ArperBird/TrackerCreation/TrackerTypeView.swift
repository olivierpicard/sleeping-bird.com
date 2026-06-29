//
//  TrackerNameView.swift
//  ArperBird
//
//  Created by Olivier Picard on 21/06/2026.
//

import SwiftUI

/// The tracker type a user can pick during manual creation. The raw value is the
/// stable identifier "Next" carries forward to the following step.
enum TrackerKind: String, CaseIterable {
    case number, duration, choices, binary, goal, date
}

struct TrackerTypeView: View {
    let name: String
    let color: Color
    let emoji: String
    var onNext: (TrackerKind) -> Void

    private let options: [TrackerTypeOption]
    @State private var selection: TrackerKind

    init(
        name: String = String(localized: "Your tracker name"),
        color: Color = .gray,
        emoji: String = "🫥",
        onNext: @escaping (TrackerKind) -> Void = { _ in }
    ) {
        self.name = name
        self.color = color
        self.emoji = emoji
        self.onNext = onNext
        let options = Self.makeOptions(color: color)
        self.options = options
        _selection = State(initialValue: options.first?.kind ?? .number)
    }

    /// The tracker type matching the currently visible carousel page.
    private var selectedOption: TrackerTypeOption? {
        options.first { $0.kind == selection }
    }

    /// CTA reflecting the highlighted type, e.g. "Select type: Date".
    private var ctaTitle: String {
        guard let option = selectedOption else {
            return String(localized: "Next")
        }
        return String(
            format: String(localized: "tracker_type.cta"),
            String(localized: option.label)
        )
    }

    var body: some View {
        VStack {
            TabView(selection: $selection) {
                ForEach(options) { option in
                    cardPage(for: option)
                        .tag(option.kind)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)

            pageIndicator

            Spacer()

            Button(action: {
                if let kind = selectedOption?.kind { onNext(kind) }
            }) {
                Text(ctaTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .padding()
        }
        .trackScreen("ManualTrackerCreationType")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("What is the tracker type ?")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func cardPage(for option: TrackerTypeOption) -> some View {
        VStack(spacing: 16) {
            MetricView(
                mainColor: color,
                header: {
                    MetricHeaderValueView(
                        title: name,
                        emoji: emoji,
                        value: "",
                        mainColor: color,
                        showAddButton: false
                    )
                },
                chart: { AnyView(MiniChartFactory.make(from: option.metric)) }
            )

            VStack(spacing: 2) {
                Text(option.label)
                    .font(.headline)
                Text(option.sublabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(option.examples)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    /// Custom page dots pinned below the carousel so they stay put while pages
    /// swipe. Replaces the built-in `.page` indicator, which we hide.
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                Circle()
                    .fill(
                        option.kind == selection
                            ? color : Color.secondary.opacity(0.3)
                    )
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Carousel options

    private struct TrackerTypeOption: Identifiable {
        var id: TrackerKind { kind }
        let kind: TrackerKind
        let label: LocalizedStringResource
        let sublabel: LocalizedStringKey
        /// Concrete real-world examples that make the abstract type tangible,
        /// e.g. "Like workouts, reading, or screen time".
        let examples: LocalizedStringKey
        let metric: Metric
    }

    private static func makeOptions(color: Color) -> [TrackerTypeOption] {
        func option(
            _ kind: TrackerKind,
            label: LocalizedStringResource,
            sublabel: LocalizedStringKey,
            examples: LocalizedStringKey,
            schema: MetricSchema,
            // Bar charts drop older values to fit the card width, so seed enough
            // days to fill it. Passed per-call so each option owns its sample
            // size, insulated from `fakeData`'s default changing under us.
            days: Int = 14
        ) -> TrackerTypeOption {
            TrackerTypeOption(
                kind: kind,
                label: label,
                sublabel: sublabel,
                examples: examples,
                metric: Metric(
                    from: schema,
                    color: color,
                    data: Metric.fakeData(for: schema.config, days: days)
                )
            )
        }

        return [
            option(
                .duration,
                label: "tracker_type.duration.label",
                sublabel: "Time spent on an activity",
                examples: "Like workouts, reading, screen time...",
                schema: MetricSchema.Fake.duration(chart: .bar),
                days: 40
            ),
            option(
                .binary,
                label: "Binary",
                sublabel: "Yes/No choices",
                examples: "Like took meds, went to the gym, ate healthy...",
                schema: MetricSchema.Fake.binary(chart: .calendar)
            ),
            option(
                .choices,
                label: "Category",
                sublabel: "Single or multiple choice",
                examples: "Like mood, meal type, symptoms...",
                schema: MetricSchema.Fake.categorySingle(chart: .pie)
            ),
            option(
                .date,
                label: "tracker_type.date.label",
                sublabel: "Save a date on calendar",
                examples: "Like a period start, last haircut, car service...",
                schema: MetricSchema.Fake.datetime(chart: .calendar)
            ),
            option(
                .goal,
                label: "tracker_type.goal.label",
                sublabel: "A goal to reach per day",
                examples: "Like steps, water intake, or calories",
                schema: MetricSchema.Fake.number(
                    min: 3_000,
                    max: 8_000,
                    goal: 10_000,
                    chart: .dailyGauge
                )
            ),
            option(
                .number,
                label: "Other",
                sublabel: "Can be represented by numbers",
                examples: "",
                schema: MetricSchema.Fake.number(goal: nil, chart: .line),
                days: 22
            ),
        ]
    }
}

#Preview {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerTypeView()
        }
    }
    .presentationDetents([.large])
}
