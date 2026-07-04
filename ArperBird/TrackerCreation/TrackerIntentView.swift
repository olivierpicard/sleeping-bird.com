//
//  TrackerIntentView.swift
//  ArperBird
//
//  Created by Olivier Picard on 05/07/2026.
//

import SwiftUI

/// UI-only mockup of the intent-based creation screen, prompt-first: a free-text
/// "describe it" field on top with hardcoded quick-fill chips, and the live
/// preview card below as the response, re-shaped by format pills. No AI, no
/// navigation, no persistence — built to evaluate the design before committing.
struct TrackerIntentView: View {
    @State private var suggestions: [IntentSuggestion]
    @State private var placeholder: Metric
    @State private var selected: IntentSuggestion?
    @State private var formatIndex = 0
    @State private var isLoading = false
    @State private var text = ""

    init() {
        _suggestions = State(initialValue: Self.makeSuggestions())
        _placeholder = State(
            initialValue: Self.metric(
                MetricSchema.Fake.number(
                    title: String(localized: "Your tracker name"),
                    emoji: "🫥",
                    goal: nil,
                    chart: .line
                ),
                color: .gray,
                days: 22
            )
        )
    }

    private var displayedMetric: Metric {
        guard let selected, !isLoading else { return placeholder }
        return selected.formats[formatIndex].metric
    }

    private var mainColor: Color {
        guard selected != nil, !isLoading else { return .gray }
        return selected?.color ?? .gray
    }

    var body: some View {
        VStack(spacing: 0) {
            inputField
                .padding(.horizontal)
                .padding(.top, 16)

            // Quick-fill examples for the field: a tap fills the prompt, then
            // the card below resolves — teaching the field→card causality.
            BadgesStackView(
                badges: suggestions.map { "\($0.name) \($0.emoji)" },
                innerPadding: 5,
                borderThickness: 0.5,
                alignment: .center,
                maxRows: 2,
                onTap: { index in resolve(suggestions[index]) }
            )
            .font(.footnote)
            .padding(.horizontal)
            .padding(.top, 14)

            Divider()
                .padding(.horizontal, 48)
                .padding(.top, 20)

            previewCard
                .padding(.horizontal)
                .padding(.top, 20)

            Text("You, three weeks from now")
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.top, 10)
                .opacity(selected != nil && !isLoading ? 1 : 0)

            formatPills
                .padding(.top, 14)

            Spacer()

            Button(action: {}) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .padding()
        }
        .navigationTitle("Add a tracker")
        .navigationSubtitle("What do you want to track ?")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Subviews

    private var previewCard: some View {
        MetricView(
            mainColor: mainColor,
            header: {
                MetricHeaderValueView(
                    title: displayedMetric.name,
                    emoji: displayedMetric.emoji,
                    value: "",
                    mainColor: mainColor,
                    showAddButton: false
                )
            },
            chart: MiniChartFactory.make(from: displayedMetric)
        )
        .redacted(reason: isLoading ? .placeholder : [])
        .animation(.snappy, value: isLoading)
    }

    /// One pill per way this suggestion can be logged; tapping re-shapes the
    /// preview instantly (in the real flow this is a local morph, no AI).
    private var formatPills: some View {
        HStack(spacing: 8) {
            if let selected, !isLoading {
                ForEach(selected.formats.indices, id: \.self) { index in
                    let format = selected.formats[index]
                    Button(action: { formatIndex = index }) {
                        Label(format.label, systemImage: format.icon)
                            .font(.footnote.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(index == formatIndex ? selected.color : .gray)
                }
            } else {
                // Reserve the row's height so the layout doesn't jump.
                Button(action: {}) {
                    Label("placeholder", systemImage: "circle")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.bordered)
                .hidden()
            }
        }
    }

    private var inputField: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.line")
                .foregroundStyle(.secondary)
            TextField("Describe what you want to track…", text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit { resolveCustom() }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemFill))
        )
    }

    // MARK: - Fake resolution (stands in for the AI classify call)

    private func resolve(_ suggestion: IntentSuggestion) {
        text = suggestion.name
        isLoading = true
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            formatIndex = 0
            selected = suggestion
            isLoading = false
        }
    }

    private func resolveCustom() {
        let name = text.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        resolve(Self.customSuggestion(named: name))
    }

    // MARK: - Hardcoded suggestions

    private struct IntentFormat {
        let label: String
        let icon: String
        let metric: Metric
    }

    private struct IntentSuggestion: Identifiable {
        let id = UUID()
        let name: String
        let emoji: String
        let color: Color
        let formats: [IntentFormat]
    }

    private static func metric(
        _ schema: MetricSchema,
        color: Color,
        days: Int = 14
    ) -> Metric {
        Metric(
            from: schema,
            color: color,
            data: Metric.fakeData(for: schema.config, days: days)
        )
    }

    private static func makeSuggestions() -> [IntentSuggestion] {
        [
            IntentSuggestion(
                name: String(localized: "Meditation"),
                emoji: "🧘",
                color: .purple,
                formats: [
                    IntentFormat(
                        label: String(localized: "Time spent"),
                        icon: "clock",
                        metric: metric(
                            MetricSchema.Fake.duration(
                                title: String(localized: "Meditation"),
                                emoji: "🧘",
                                chart: .bar
                            ),
                            color: .purple,
                            days: 40
                        )
                    ),
                    IntentFormat(
                        label: String(localized: "Yes / No"),
                        icon: "checkmark.circle",
                        metric: metric(
                            MetricSchema.Fake.binary(
                                title: String(localized: "Meditation"),
                                emoji: "🧘",
                                chart: .calendar
                            ),
                            color: .purple
                        )
                    ),
                    IntentFormat(
                        label: String(localized: "Daily goal"),
                        icon: "target",
                        metric: metric(
                            MetricSchema.Fake.number(
                                title: String(localized: "Meditation"),
                                emoji: "🧘",
                                unit: "min",
                                min: 0,
                                max: 30,
                                granularity: 5,
                                goal: 20,
                                chart: .dailyGauge
                            ),
                            color: .purple
                        )
                    ),
                ]
            ),
            IntentSuggestion(
                name: String(localized: "Coffee"),
                emoji: "☕️",
                color: .brown,
                formats: [
                    IntentFormat(
                        label: String(localized: "A number"),
                        icon: "number",
                        metric: metric(
                            MetricSchema.Fake.number(
                                title: String(localized: "Coffee"),
                                emoji: "☕️",
                                unit: String(localized: "cups"),
                                min: 0,
                                max: 8,
                                granularity: 1,
                                goal: nil,
                                chart: .bar
                            ),
                            color: .brown,
                            days: 40
                        )
                    ),
                    IntentFormat(
                        label: String(localized: "Yes / No"),
                        icon: "checkmark.circle",
                        metric: metric(
                            MetricSchema.Fake.binary(
                                title: String(localized: "Coffee"),
                                emoji: "☕️",
                                chart: .calendar
                            ),
                            color: .brown
                        )
                    ),
                ]
            ),
            IntentSuggestion(
                name: String(localized: "Mood"),
                emoji: "🙂",
                color: .yellow,
                formats: [
                    IntentFormat(
                        label: String(localized: "Pick from a list"),
                        icon: "list.bullet",
                        metric: metric(
                            MetricSchema.Fake.categorySingle(
                                title: String(localized: "Mood"),
                                emoji: "🙂",
                                chart: .pie
                            ),
                            color: .yellow
                        )
                    ),
                ]
            ),
            IntentSuggestion(
                name: String(localized: "Sleep"),
                emoji: "😴",
                color: .indigo,
                formats: [
                    IntentFormat(
                        label: String(localized: "Time spent"),
                        icon: "clock",
                        metric: metric(
                            MetricSchema.Fake.duration(
                                title: String(localized: "Sleep"),
                                emoji: "😴",
                                maxInSeconds: 32_400,
                                chart: .bar
                            ),
                            color: .indigo,
                            days: 40
                        )
                    ),
                    IntentFormat(
                        label: String(localized: "Yes / No"),
                        icon: "checkmark.circle",
                        metric: metric(
                            MetricSchema.Fake.binary(
                                title: String(localized: "Sleep"),
                                emoji: "😴",
                                chart: .calendar
                            ),
                            color: .indigo
                        )
                    ),
                ]
            ),
            IntentSuggestion(
                name: String(localized: "Steps"),
                emoji: "👟",
                color: .green,
                formats: [
                    IntentFormat(
                        label: String(localized: "Daily goal"),
                        icon: "target",
                        metric: metric(
                            MetricSchema.Fake.number(
                                title: String(localized: "Steps"),
                                emoji: "👟",
                                min: 3_000,
                                max: 8_000,
                                goal: 10_000,
                                chart: .dailyGauge
                            ),
                            color: .green
                        )
                    ),
                    IntentFormat(
                        label: String(localized: "A number"),
                        icon: "number",
                        metric: metric(
                            MetricSchema.Fake.number(
                                title: String(localized: "Steps"),
                                emoji: "👟",
                                goal: nil,
                                chart: .bar
                            ),
                            color: .green,
                            days: 40
                        )
                    ),
                ]
            ),
            IntentSuggestion(
                name: String(localized: "Haircut"),
                emoji: "💇",
                color: .pink,
                formats: [
                    IntentFormat(
                        label: String(localized: "A date"),
                        icon: "calendar",
                        metric: metric(
                            MetricSchema.Fake.datetime(
                                title: String(localized: "Haircut"),
                                emoji: "💇",
                                chart: .calendar
                            ),
                            color: .pink
                        )
                    ),
                ]
            ),
            IntentSuggestion(
                name: String(localized: "Reading"),
                emoji: "📚",
                color: .orange,
                formats: [
                    IntentFormat(
                        label: String(localized: "Time spent"),
                        icon: "clock",
                        metric: metric(
                            MetricSchema.Fake.duration(
                                title: String(localized: "Reading"),
                                emoji: "📚",
                                chart: .bar
                            ),
                            color: .orange,
                            days: 40
                        )
                    ),
                    IntentFormat(
                        label: String(localized: "Yes / No"),
                        icon: "checkmark.circle",
                        metric: metric(
                            MetricSchema.Fake.binary(
                                title: String(localized: "Reading"),
                                emoji: "📚",
                                chart: .calendar
                            ),
                            color: .orange
                        )
                    ),
                ]
            ),
        ]
    }

    /// Stand-in for what the AI would return for free text: same name the user
    /// typed, generic number shape.
    private static func customSuggestion(named name: String) -> IntentSuggestion {
        IntentSuggestion(
            name: name,
            emoji: "📊",
            color: .teal,
            formats: [
                IntentFormat(
                    label: String(localized: "A number"),
                    icon: "number",
                    metric: metric(
                        MetricSchema.Fake.number(
                            title: name,
                            emoji: "📊",
                            unit: nil,
                            goal: nil,
                            chart: .line
                        ),
                        color: .teal,
                        days: 22
                    )
                ),
                IntentFormat(
                    label: String(localized: "Yes / No"),
                    icon: "checkmark.circle",
                    metric: metric(
                        MetricSchema.Fake.binary(
                            title: name,
                            emoji: "📊",
                            chart: .calendar
                        ),
                        color: .teal
                    )
                ),
            ]
        )
    }
}

#Preview {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerIntentView()
        }
        .environment(\.locale, Locale(identifier: "en_US"))
    }
    .presentationDetents([.large])
}
