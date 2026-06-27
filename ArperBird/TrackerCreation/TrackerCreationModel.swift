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

    // MARK: - Category sub-flow

    /// Loading state of the category auto-completion request.
    private(set) var categoryPhase: Phase = .idle
    /// The AI-suggested labels, used to *seed* the editable labels screen. The
    /// user can then add, rename, or delete rows; their final list is written
    /// back here on "Next" — so this property is both the seed and the result,
    /// mirroring how `durationMaxSeconds` works on the duration path.
    var categoryLabels: [String] = []
    /// The AI's *original* suggested labels, kept separately so we can tell
    /// whether the user replaced or deleted any of them — `categoryLabels` is
    /// overwritten with the user's final list on "Next", so it can't be diffed
    /// against the suggestion. See `shouldReclassifyChoice(for:)`.
    private(set) var categorySuggestedLabels: [String] = []
    /// Whether several picks are allowed per entry (multiple choice) rather than
    /// exactly one (single choice). Seeded from the AI's judgment during loading,
    /// then confirmed (or flipped) by the user on the category-type screen — so,
    /// like `categoryLabels`, this is both the seed and the result.
    var categoryAllowsMultiple = false
    var categoryEmoji = ""

    /// Seam over the category AI call, mirroring `generate`. Takes the tracker
    /// name.
    private let generateCategory: (String) async throws -> CategoryAiCompletionSchema
    /// The name the category suggestion was loaded for. Guards the fetch so it
    /// runs once per name and never re-fires on back-navigation.
    private var loadedCategoryName: String?

    // MARK: - Binary sub-flow

    /// Loading state of the binary emoji auto-completion request.
    private(set) var binaryPhase: Phase = .idle
    /// The AI-suggested emoji for the binary tracker. The binary path needs
    /// nothing else from the AI — it goes straight from naming to the reveal —
    /// so this is the lone result of its loading step.
    var binaryEmoji = ""

    /// Seam over the emoji AI call, mirroring `generateDuration`. Shared by the
    /// binary and date paths — both need only an emoji from the AI. Takes the
    /// tracker name.
    private let generateEmoji: (String) async throws -> EmojiAiCompletionSchema
    /// The name `binaryEmoji` was loaded for. Guards the fetch so it runs once
    /// per name and never re-fires on back-navigation.
    private var loadedBinaryName: String?

    // MARK: - Number sub-flow

    /// Loading state of the number auto-completion request.
    private(set) var numberPhase: Phase = .idle
    /// The AI-proposed units for the open-ended number tracker, each carrying a
    /// realistic max and natural granularity. Populated once per name and read by
    /// the unit list and the max screen alike.
    private(set) var numberSuggestions: [NumberAiCompletionSchema] = []
    /// The unit, upper bound, granularity and emoji assembled across the number
    /// pages. Seeded from the chosen suggestion, then refined on the max screen.
    /// `behavior` (above) is shared with the number-type screen on the custom path.
    var numberUnit = ""
    var numberMax: Double = 0
    var numberGranularity: Double = 1
    var numberEmoji = ""
    /// Whether the AI judged this number to have a hard upper bound (e.g. a rating
    /// out of 10) rather than an open-ended estimate (e.g. steps). When bounded the
    /// max is fixed by the metric itself, so the reveal hides its editable Max chip.
    var numberIsBounded = false

    /// Seam over the number AI call, mirroring `generate`. Takes the tracker name.
    private let generateNumber: (String) async throws -> NumberAiCompletionListSchema
    /// The name the number suggestions were loaded for. Guards the fetch so it
    /// runs once per name and never re-fires on back-navigation.
    private var loadedNumberName: String?

    // MARK: - Date sub-flow

    /// Loading state of the date emoji auto-completion request.
    private(set) var datePhase: Phase = .idle
    /// The AI-suggested emoji for the date tracker. Like the binary path, the
    /// date path needs nothing else from the AI — it goes straight from naming to
    /// the reveal — so this is the lone result of its loading step.
    var dateEmoji = ""
    /// The name `dateEmoji` was loaded for. Guards the fetch so it runs once per
    /// name and never re-fires on back-navigation.
    private var loadedDateName: String?

    init(
        generate: @escaping (String) async throws -> [GoalAiCompletionSchema] = {
            try await GoalAiCompletion().generate(for: "- Tracker name: \($0)")
        },
        generateDuration: @escaping (String) async throws -> DurationAiCompletionSchema = {
            try await DurationAiCompletion().generate(for: "- Tracker name: \($0)")
        },
        generateCategory: @escaping (String) async throws -> CategoryAiCompletionSchema = {
            try await CategoryAiCompletion().generate(for: "- Tracker name: \($0)")
        },
        generateEmoji: @escaping (String) async throws -> EmojiAiCompletionSchema = {
            try await EmojiAiCompletion().generate(for: "- Tracker name: \($0)")
        },
        generateNumber: @escaping (String) async throws -> NumberAiCompletionListSchema = {
            try await NumberAiCompletion().generate(for: "- Tracker name: \($0)")
        }
    ) {
        self.generate = generate
        self.generateDuration = generateDuration
        self.generateCategory = generateCategory
        self.generateEmoji = generateEmoji
        self.generateNumber = generateNumber
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

    // MARK: - Binary completion

    /// Fetches the binary emoji for `name`, but only when it hasn't already been
    /// loaded for that name (or the previous attempt failed). Re-entrant calls —
    /// e.g. returning to the loading screen — are no-ops, so the AI never
    /// re-triggers on back-navigation.
    func loadBinaryEmojiIfNeeded() async {
        guard loadedBinaryName != name || binaryPhase == .failed else { return }
        binaryPhase = .loading
        do {
            let schema = try await generateEmoji(name)
            binaryEmoji = schema.emoji
            loadedBinaryName = name
            binaryPhase = .loaded
        } catch {
            binaryPhase = .failed
        }
    }

    // MARK: - Date completion

    /// Fetches the date emoji for `name`, but only when it hasn't already been
    /// loaded for that name (or the previous attempt failed). Re-entrant calls —
    /// e.g. returning to the loading screen — are no-ops, so the AI never
    /// re-triggers on back-navigation. Mirrors `loadBinaryEmojiIfNeeded`.
    func loadDateEmojiIfNeeded() async {
        guard loadedDateName != name || datePhase == .failed else { return }
        datePhase = .loading
        do {
            let schema = try await generateEmoji(name)
            dateEmoji = schema.emoji
            loadedDateName = name
            datePhase = .loaded
        } catch {
            datePhase = .failed
        }
    }

    // MARK: - Number completion

    /// Fetches the number units (max + granularity), shared emoji and behavior for
    /// `name`, but only when they haven't already been loaded for that name (or the
    /// previous attempt failed). Re-entrant calls — e.g. returning to the loading
    /// screen — are no-ops, so the AI never re-triggers on back-navigation. Seeds
    /// the selection with the first suggestion so the unit list and max screen have
    /// a value to show before the user picks.
    func loadNumberIfNeeded() async {
        guard loadedNumberName != name || numberPhase == .failed else { return }
        numberPhase = .loading
        do {
            let schema = try await generateNumber(name)
            numberSuggestions = schema.constraints
            behavior = schema.isCumulative ? .cumulative : .snapshot
            numberEmoji = schema.emoji
            numberIsBounded = schema.isBounded
            if let first = schema.constraints.first {
                numberUnit = first.unit ?? ""
                numberMax = first.typicalMax
                numberGranularity = first.granularity
            }
            loadedNumberName = schema.constraints.isEmpty ? nil : name
            numberPhase = schema.constraints.isEmpty ? .failed : .loaded
        } catch {
            numberPhase = .failed
        }
    }

    /// Commit the unit chosen on the number unit list, re-anchoring the suggested
    /// max and granularity when the unit matches a suggestion; a custom unit falls
    /// back to neutral round defaults the user then dials in on the max page. The
    /// emoji is list-level, so it stays put regardless of the chosen unit.
    func chooseNumberUnit(_ unit: String) {
        numberUnit = unit
        if let match = numberSuggestions.first(where: { $0.unit == unit }) {
            numberMax = match.typicalMax
            numberGranularity = match.granularity
        } else {
            numberMax = 100
            numberGranularity = 1
        }
    }

    /// Persist the upper bound the user dialled in on the max screen, overriding the
    /// AI suggestion. A method because `numberMax` is otherwise `private`-seeded to
    /// keep the load memoization the single writer of the suggestion values.
    func setNumberMax(_ value: Double) {
        numberMax = max(0, value)
    }

    // MARK: - Category completion

    /// Fetches the category suggestion (labels + single/multiple + emoji) for
    /// `name`, but only when it hasn't already been loaded for that name (or the
    /// previous attempt failed). Re-entrant calls are no-ops, so the AI never
    /// re-triggers on back-navigation — and any edits the user made to
    /// `categoryLabels` survive, since a no-op load leaves them untouched.
    func loadCategoryIfNeeded() async {
        guard loadedCategoryName != name || categoryPhase == .failed else { return }
        categoryPhase = .loading
        do {
            let schema = try await generateCategory(name)
            categoryLabels = schema.categories
            categorySuggestedLabels = schema.categories
            categoryAllowsMultiple = schema.allowsMultipleSelection
            categoryEmoji = schema.emoji
            loadedCategoryName = name
            categoryPhase = .loaded
        } catch {
            categoryPhase = .failed
        }
    }

    /// Whether the user's final labels diverge enough from the AI's suggestion to
    /// warrant re-deriving the single/multiple flag. The first guess was made from
    /// the tracker name alone; replacing or deleting a suggested label is the
    /// signal it misread the metric. Additions are ignored — they don't
    /// contradict the AI's read — so this is a subset check, normalized for
    /// whitespace and case so incidental edits don't trip it.
    func shouldReclassifyChoice(for finalLabels: [String]) -> Bool {
        let norm: (String) -> String = {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let seed = Set(categorySuggestedLabels.map(norm))
        // A replace or delete drops one of the AI's labels from the final set.
        return !seed.isSubset(of: Set(finalLabels.map(norm)))
    }

    /// Re-asks the AI for *only* the single/multiple flag, now that the user's
    /// real labels are known — keeping everything else (labels, emoji) the user
    /// settled on. Drives `categoryPhase` so the loading screen can show its
    /// spinner / retry, and passes the labels through the existing
    /// `generateCategory` seam so the AI judges with them in hand.
    func reclassifyChoice(for labels: [String]) async {
        categoryPhase = .loading
        do {
            let schema = try await generateCategory(
                "\(name)\n- Categories: \(labels.joined(separator: ", "))"
            )
            categoryAllowsMultiple = schema.allowsMultipleSelection
            categoryPhase = .loaded
        } catch {
            categoryPhase = .failed
        }
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
