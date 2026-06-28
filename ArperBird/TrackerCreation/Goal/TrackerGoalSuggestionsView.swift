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
/// either accepts a card as-is (Next) or tweaks it (Edit); both branches are
/// driven by the enclosing `TrackerCreationFlow` via the closures below.
struct TrackerGoalSuggestionsView: View {
    /// The flow's shared state. The view reads `name`/`suggestions`/`phase` from
    /// it and asks it to load — the model memoizes the fetch, so reappearing
    /// after a pop reuses the result instead of re-triggering the AI.
    let model: TrackerCreationModel
    let color: Color
    /// The visible card was accepted as-is.
    var onNext: (GoalAiCompletionSchema) -> Void
    /// "Edit" was tapped on the visible card. The full suggestion list already
    /// lives on `model`, so only the chosen card is handed back.
    var onEdit: (GoalAiCompletionSchema) -> Void

    /// Display cards derived from `model.suggestions`. Cached in local `@State`
    /// (which a covered destination retains) so the preview gauges — seeded with
    /// random fake data — don't rebuild and flicker on every render or pop-back.
    @State private var cards: [Suggestion] = []
    @State private var selection: Suggestion.ID?

    init(
        model: TrackerCreationModel,
        color: Color = .accent,
        onNext: @escaping (GoalAiCompletionSchema) -> Void = { _ in },
        onEdit: @escaping (GoalAiCompletionSchema) -> Void = { _ in }
    ) {
        self.model = model
        self.color = color
        self.onNext = onNext
        self.onEdit = onEdit
    }

    /// The suggestion backing the currently visible carousel page.
    private var selectedSuggestion: Suggestion? {
        cards.first { $0.id == selection }
    }

    var body: some View {
        VStack {
            switch model.phase {
            case .idle, .loading:
                loadingState
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
                // The model is loaded but this fresh view instance may not have
                // built its cards yet; hold the spinner until it has.
                if cards.isEmpty {
                    loadingState
                } else {
                    carousel
                    actionBar
                }
            }
        }
        .task { await load() }
        .trackScreen("ManualTrackerCreationGoalSuggestions")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("Pick a goal to track")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var loadingState: some View {
        Spacer()
        ProgressView("Finding goals…")
        Spacer()
    }

    // MARK: - Carousel

    private var carousel: some View {
        VStack {
            TabView(selection: $selection) {
                ForEach(cards) { suggestion in
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
                    MetricHeaderValueView(
                        title: model.name,
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
            ForEach(cards) { suggestion in
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
            Button(action: {
                if let selected = selectedSuggestion {
                    onEdit(selected.schema)
                }
            }) {
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

    /// Asks the model to load (a no-op once it already has, so a pop-back never
    /// re-triggers the AI), then builds the display cards once. Because `cards`
    /// is retained `@State`, the rebuild is skipped on reappearance — keeping the
    /// current page and avoiding gauge flicker.
    @MainActor
    private func load() async {
        await model.loadSuggestionsIfNeeded()
        guard cards.isEmpty, !model.suggestions.isEmpty else { return }
        let built = model.suggestions.map {
            Suggestion(
                schema: $0,
                metric: Self.metric(for: $0, name: model.name, color: color)
            )
        }
        cards = built
        selection = built.first?.id
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
    @Previewable @State var model: TrackerCreationModel = {
        let model = TrackerCreationModel(
            generate: { try await GoalAiCompletion().generateFake(for: $0) }
        )
        model.name = "Drink more water"
        return model
    }()
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerGoalSuggestionsView(model: model)
        }
    }
    .presentationDetents([.large])
}
