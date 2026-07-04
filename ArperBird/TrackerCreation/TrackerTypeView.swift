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
    /// A tap on one of a page's example chips — a shortcut that seeds the flow
    /// with the suggestion's name and kind, skipping the naming step.
    var onSuggestion: (TrackerSuggestion) -> Void

    private let options: [TrackerTypeOption]
    @State private var selection: TrackerKind

    init(
        name: String = String(localized: "Your tracker name"),
        color: Color = .gray,
        emoji: String = "🫥",
        onNext: @escaping (TrackerKind) -> Void = { _ in },
        onSuggestion: @escaping (TrackerSuggestion) -> Void = { _ in }
    ) {
        self.name = name
        self.color = color
        self.emoji = emoji
        self.onNext = onNext
        self.onSuggestion = onSuggestion
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
                        .padding(.top, 36)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 380)

            pageIndicator
//                .padding(.bottom, 100)

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
                chart: MiniChartFactory.make(from: option.metric)
            )
            
            VStack(spacing: 2) {
                Text(option.label)
                    .font(.headline)
                Text(option.sublabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                // Tappable counterparts of the examples caption this replaces:
                // each chip seeds the flow with its name + this page's kind.
                BadgesStackView(
                    badges: option.suggestions.map(\.label),
                    innerPadding: 5,
                    borderThickness: 0.5,
                    alignment: .center,
                    maxRows: 2,
                    onTap: { index in
                        onSuggestion(option.suggestions[index])
                    }
                )
                .font(.footnote)
                .padding(.top, 8)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity, alignment: .top)
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
        /// Concrete real-world ideas that make the abstract type tangible,
        /// shown as tappable chips that shortcut into the kind's flow.
        let suggestions: [TrackerSuggestion]
        let metric: Metric
    }

    private static func makeOptions(color: Color) -> [TrackerTypeOption] {
        func option(
            _ kind: TrackerKind,
            label: LocalizedStringResource,
            sublabel: LocalizedStringKey,
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
                suggestions: TrackerSuggestion.examples(for: kind),
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
                schema: MetricSchema.Fake.duration(chart: .bar),
                days: 40
            ),
            option(
                .binary,
                label: "Binary",
                sublabel: "Yes/No choices",
                schema: MetricSchema.Fake.binary(chart: .calendar)
            ),
            option(
                .choices,
                label: "Category",
                sublabel: "Single or multiple choice",
                schema: MetricSchema.Fake.categorySingle(chart: .pie)
            ),
            option(
                .date,
                label: "tracker_type.date.label",
                sublabel: "Save a date on calendar",
                schema: MetricSchema.Fake.datetime(chart: .calendar)
            ),
            option(
                .goal,
                label: "tracker_type.goal.label",
                sublabel: "A goal to reach per day",
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
        .environment(\.locale, Locale(identifier: "en_US"))
    }
    .presentationDetents([.large])
}
