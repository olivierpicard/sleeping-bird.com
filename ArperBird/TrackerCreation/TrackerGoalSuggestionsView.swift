//
//  TrackerGoalSuggestionsView.swift
//  ArperBird
//
//  Created by Olivier Picard on 23/06/2026.
//

import SwiftUI

/// The step that follows naming on the `goal` path. It hands the tracker name to
/// `GoalAiCompletion`, which proposes a few ready-made ways to track it — unit,
/// daily target, emoji — and presents them as swipeable preview cards. The user
/// picks one (Next) or tweaks it (Edit, not yet wired).
struct TrackerGoalSuggestionsView: View {
    let name: String
    let color: Color
    /// Seam over the AI call so previews/tests can supply suggestions without a
    /// network round-trip. Defaults to the real `GoalAiCompletion`.
    var generate: (String) async throws -> [GoalAiCompletionSchema]
    var onNext: (GoalAiCompletionSchema) -> Void

    @State private var suggestions: [Suggestion] = []
    @State private var selection: Suggestion.ID?
    @State private var phase: Phase = .loading
    @State private var isEditingUnit = false

    private enum Phase { case loading, loaded, failed }

    init(
        name: String = "Daily steps",
        color: Color = .accent,
        generate: @escaping (String) async throws -> [GoalAiCompletionSchema] = {
            try await GoalAiCompletion().generate(for: $0)
        },
        onNext: @escaping (GoalAiCompletionSchema) -> Void = { _ in }
    ) {
        self.name = name
        self.color = color
        self.generate = generate
        self.onNext = onNext
    }

    /// The suggestion backing the currently visible carousel page.
    private var selectedSuggestion: Suggestion? {
        suggestions.first { $0.id == selection }
    }

    var body: some View {
        VStack {
            switch phase {
            case .loading:
                Spacer()
                ProgressView("Finding goals…")
                Spacer()
            case .failed:
                Spacer()
                ContentUnavailableView {
                    Label("Couldn't suggest goals", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(action: { Task { await load() } }) {
                        Text("Try again")
                    }
                }
                Spacer()
            case .loaded:
                carousel
                actionBar
            }
        }
        .task { await load() }
        .navigationDestination(isPresented: $isEditingUnit) {
            // Page 1 of the edit sub-flow. Page 2 (the daily goal) is wired
            // through `onNext` in a later step.
            TrackerGoalUnitListView(
                name: name,
                options: suggestions.map {
                    .init(unit: $0.schema.unit, dailyGoal: $0.schema.dailyGoal)
                },
                selectedUnit: selectedSuggestion?.schema.unit,
                color: color
            )
        }
        .trackScreen("ManualTrackerCreationGoalSuggestions")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Pick a goal to track")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Carousel

    private var carousel: some View {
        VStack {
            TabView(selection: $selection) {
                ForEach(suggestions) { suggestion in
                    cardPage(for: suggestion)
                        .tag(suggestion.id as Suggestion.ID?)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 250)

            pageIndicator

            Spacer() 
        }
    }

    @ViewBuilder
    private func cardPage(for suggestion: Suggestion) -> some View {
        VStack(spacing: 16) {
            MetricView(
                mainColor: color,
                header: {
                    MetricHeaderTextView(
                        title: name,
                        emoji: suggestion.schema.emoji,
                        value: valueText(for: suggestion.schema),
                        mainColor: color,
                        showAddButton: false
                    )
                },
                chart: { AnyView(MiniChartFactory.make(from: suggestion.metric)) }
            )

        }
        .padding(.horizontal)
    }

    /// Custom page dots pinned below the carousel so they stay put while pages
    /// swipe. Mirrors `TrackerTypeView`'s indicator.
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(suggestions) { suggestion in
                Circle()
                    .fill(
                        suggestion.id == selection
                            ? color : Color.secondary.opacity(0.3)
                    )
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 12) {
            // Branches into the unit/goal edit sub-flow for the visible card.
            Button(action: { isEditingUnit = true }) {
                Label("Edit", systemImage: "pencil")
                    .font(.headline)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glass)
            .disabled(selectedSuggestion == nil)

            Button(action: {
                if let schema = selectedSuggestion?.schema { onNext(schema) }
            }) {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .disabled(selectedSuggestion == nil)
        }
        .padding()
    }

    // MARK: - Loading

    @MainActor
    private func load() async {
        phase = .loading
        do {
            let goals = try await generate(name)
            let built = goals.map {
                Suggestion(
                    schema: $0,
                    metric: Self.metric(for: $0, name: name, color: color)
                )
            }
            suggestions = built
            selection = built.first?.id
            phase = built.isEmpty ? .failed : .loaded
        } catch {
            phase = .failed
        }
    }

    // MARK: - Formatting

    /// The big header number, e.g. "10,000 steps".
    private func valueText(for schema: GoalAiCompletionSchema) -> String {
        "\(schema.dailyGoal.formatted(.number)) \(schema.unit)"
    }

    // MARK: - Card model

    private struct Suggestion: Identifiable {
        let id = UUID()
        let schema: GoalAiCompletionSchema
        let metric: Metric
    }

    /// Turns a goal suggestion into a daily-gauge metric so the card previews the
    /// same chart the real tracker will render. Seeded with fake data so the gauge
    /// shows a partial fill rather than the empty state.
    private static func metric(
        for schema: GoalAiCompletionSchema,
        name: String,
        color: Color
    ) -> Metric {
        let config = MetricSchema(
            name: name,
            emoji: schema.emoji,
            fitPercentage: 1,
            config: .number(
                NumberConfig(
                    min: 0,
                    max: schema.dailyGoal,
                    granularity: schema.dailyGoal >= 50 ? 1 : 0.1,
                    unit: schema.unit,
                    goal: schema.dailyGoal,
                    behavior: .cumulative
                )
            ),
            visual: MetricVisual(
                chart: .dailyGauge,
                aggregation: AggregationConfig(
                    bucket: .daily,
                    method: .numerical(.sum)
                )
            )
        )
        return Metric(
            from: config,
            color: color,
            data: Metric.fakeData(for: config.config)
        )
    }
}

#Preview {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerGoalSuggestionsView(
                name: "Drink more water",
                generate: { try await GoalAiCompletion().generateFake(for: $0) }
            )
        }
    }
    .presentationDetents([.large])
}
