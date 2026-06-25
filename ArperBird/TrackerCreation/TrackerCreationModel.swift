//
//  TrackerCreationModel.swift
//  ArperBird
//
//  Created by Olivier Picard on 24/06/2026.
//

import Foundation

/// Single source of truth for the manual tracker-creation flow.
///
/// Owning the flow's state in one `@Observable` object — rather than threading
/// it through per-step `@State` and `NavigationPath` payloads — is what makes the
/// data survive back-navigation. In particular it owns the goal AI suggestions
/// and *memoizes* the fetch (`loadSuggestionsIfNeeded`), so revealing the
/// suggestions screen again after a pop reuses the result instead of re-hitting
/// the model. It is also the one home for the unit re-anchoring rule that used to
/// be duplicated across the coordinator.
@MainActor
@Observable
final class TrackerCreationModel {
    /// Loading state of the goal-suggestions request.
    enum Phase: Equatable { case idle, loading, loaded, failed }

    // MARK: - Type path

    var kind: TrackerKind?
    var behavior: MetricBehavior?
    var categoryLabels: [String] = []
    var name = ""

    // MARK: - Goal sub-flow

    private(set) var phase: Phase = .idle
    /// Every AI-proposed way to track the goal. Populated once per name and read
    /// by the suggestions carousel and the unit list alike — so the data reaches
    /// the unit screen whether the user tapped "Next" or "Edit".
    private(set) var suggestions: [GoalAiCompletionSchema] = []

    /// The unit, daily target and emoji assembled across the goal edit pages.
    /// Seeded from the chosen suggestion, then refined on the value page.
    var selectedUnit = ""
    var goalValue: Double = 0
    var goalEmoji = ""

    /// Seam over the AI call so previews/tests supply suggestions without a
    /// network round-trip. Takes the tracker name.
    private let generate: (String) async throws -> [GoalAiCompletionSchema]
    /// The name the current `suggestions` were loaded for. Guards the fetch so it
    /// runs once per name and never re-fires on back-navigation.
    private var loadedName: String?

    // MARK: - Duration sub-flow

    /// Loading state of the duration auto-completion request.
    private(set) var durationPhase: Phase = .idle
    /// The AI-suggested upper bound for the duration wheel, in seconds, and a
    /// matching emoji. Populated once per name from `DurationAiCompletion`.
    private(set) var durationMaxSeconds = 0
    var durationEmoji = ""

    /// Seam over the duration AI call, mirroring `generate`. Takes the tracker
    /// name.
    private let generateDuration: (String) async throws -> DurationAiCompletionSchema
    /// The name `durationMaxSeconds`/`durationEmoji` were loaded for. Guards the
    /// fetch so it runs once per name and never re-fires on back-navigation.
    private var loadedDurationName: String?

    init(
        generate: @escaping (String) async throws -> [GoalAiCompletionSchema] = {
            try await GoalAiCompletion().generate(for: "- Tracker name: \($0)")
        },
        generateDuration: @escaping (String) async throws -> DurationAiCompletionSchema = {
            try await DurationAiCompletion().generate(for: "- Tracker name: \($0)")
        }
    ) {
        self.generate = generate
        self.generateDuration = generateDuration
    }

    // MARK: - Goal suggestions

    /// Fetches goal suggestions for `name`, but only when they haven't already
    /// been loaded for that name (or the previous attempt failed). Re-entrant
    /// calls — e.g. the suggestions screen reappearing after a pop — are no-ops,
    /// which is what stops the AI from re-triggering.
    func loadSuggestionsIfNeeded() async {
        guard loadedName != name || phase == .failed else { return }
        phase = .loading
        do {
            let goals = try await generate(name)
            suggestions = goals
            loadedName = goals.isEmpty ? nil : name
            phase = goals.isEmpty ? .failed : .loaded
        } catch {
            phase = .failed
        }
    }

    // MARK: - Duration completion

    /// Fetches the duration config (max wheel value + emoji) for `name`, but only
    /// when it hasn't already been loaded for that name (or the previous attempt
    /// failed). Re-entrant calls — e.g. returning to the loading screen — are
    /// no-ops, so the AI never re-triggers on back-navigation.
    func loadDurationIfNeeded() async {
        guard loadedDurationName != name || durationPhase == .failed else { return }
        durationPhase = .loading
        do {
            let schema = try await generateDuration(name)
            durationMaxSeconds = schema.maxInSeconds
            durationEmoji = schema.emoji
            loadedDurationName = name
            durationPhase = .loaded
        } catch {
            durationPhase = .failed
        }
    }

    /// Persist the upper bound the user dialled in on the duration config wheels,
    /// overriding the AI suggestion. A method because `durationMaxSeconds` is
    /// otherwise `private(set)` to protect the load memoization.
    func setDurationMax(_ seconds: Int) {
        durationMaxSeconds = max(0, seconds)
    }

    // MARK: - Goal selection

    /// Adopt a suggestion wholesale — the entry point for both "Next" (accept as
    /// is) and "Edit" (then refine on the following pages).
    func select(_ schema: GoalAiCompletionSchema) {
        selectedUnit = schema.unit
        goalValue = schema.dailyGoal
        goalEmoji = schema.emoji
    }

    /// Commit the unit chosen on the unit list, re-anchoring the suggested value
    /// and emoji when the unit matches a suggestion; a custom unit keeps whatever
    /// value was carried in.
    func chooseUnit(_ unit: String) {
        selectedUnit = unit
        if let match = suggestions.first(where: { $0.unit == unit }) {
            goalValue = match.dailyGoal
            goalEmoji = match.emoji
        }
    }
}
