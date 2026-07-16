//
//  TrackerCreationModel.swift
//  ArperBird
//
//  Created by Olivier Picard on 24/06/2026.
//

import Foundation
import SwiftUI

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
    /// The tracker's resolved color, seeded from the intent screen's per-kind
    /// color once the user continues. Lives on the model (not the flow's own
    /// `@State`) so every read is against the same live class instance
    /// regardless of which struct snapshot a `NavigationStack` destination
    /// closure was built from — a plain `@State var` on the flow view could
    /// otherwise still read the pre-resolution `.accent` default on the very
    /// first push of a session. Defaults to the app accent pre-resolution.
    var color: Color = .accent

    /// The corrected color for text-bearing controls (chips, CTAs, steppers),
    /// derived from `color` the same way `Metric.displayColor(in:)` derives a
    /// dashboard card's control color from its raw fill. Takes `colorScheme`
    /// as a parameter — that's environment-only information the model itself
    /// doesn't own — so each view calls this with its own
    /// `@Environment(\.colorScheme)` rather than being handed the result.
    func mainColor(in colorScheme: ColorScheme) -> Color {
        color.readableControlTint(in: colorScheme)
    }

    var name = "" {
        // The hint described the suggestion chip, not whatever the user typed —
        // editing the name invalidates it.
        didSet { if name != oldValue { aiHint = nil } }
    }
    /// English-only context seeded from a suggestion chip, appended to the AI
    /// instruction alongside the name. Nil for typed names.
    var aiHint: String?

    /// The tracker's emoji, routed to whichever per-kind field backs the active
    /// `kind` — the same field `TrackerCreationFlow.doneSchema()` reads. Lets the
    /// reveal edit "the emoji" without caring which path it came from, so the edit
    /// lands on the metric that's actually persisted.
    var emoji: String {
        get {
            switch kind {
            case .goal: goalEmoji
            case .duration: durationEmoji
            case .choices: categoryEmoji
            case .binary: binaryEmoji
            case .date: dateEmoji
            case .number: numberEmoji
            case nil: ""
            }
        }
        set {
            switch kind {
            case .goal: goalEmoji = newValue
            case .duration: durationEmoji = newValue
            case .choices: categoryEmoji = newValue
            case .binary: binaryEmoji = newValue
            case .date: dateEmoji = newValue
            case .number: numberEmoji = newValue
            case nil: break
            }
        }
    }

    // MARK: - Goal sub-flow

    private(set) var phase: Phase = .idle
    /// Every AI-proposed way to track the goal. Populated once per name and read
    /// by the suggestions carousel and the unit list alike — so the data reaches
    /// the unit screen whether the user tapped "Next" or "Edit".
    private(set) var suggestions: [GoalAiCompletionSchema] = []

    /// The unit and daily target assembled across the goal edit pages, seeded from
    /// the chosen suggestion and refined on the value page.
    var selectedUnit = ""
    var goalValue: Double = 0
    /// A single emoji for the whole goal. The AI proposes it at the suggestion-list
    /// level (not per unit), so it's seeded once at load and stays put when the unit
    /// changes — mirroring how the number path keeps `numberEmoji` list-level.
    var goalEmoji = ""
    /// The step between goal entries, seeded from the chosen suggestion and dialed
    /// in on the reveal's Step chip. AI units carry their own step; a custom unit has
    /// none, so it re-anchors to the neutral `1` and the granularity loading step
    /// then fetches one tuned to that unit — see `loadGoalGranularityIfNeeded`.
    var goalGranularity: Double = 1

    /// The custom unit the user typed (the one the AI didn't propose), remembered
    /// so the reveal's unit menu keeps offering it after they switch to an AI unit.
    /// Captured the moment they switch *away* from a custom unit; nil until then.
    private(set) var goalCustomUnit: String?
    /// The target and step the user had dialed for `goalCustomUnit`, stashed
    /// alongside it so re-picking the custom unit restores its figures rather than
    /// the AI default. The emoji isn't stashed — it's list-level, shared across
    /// every unit.
    private var goalCustomValue: Double = 0
    private var goalCustomGranularity: Double = 1

    /// Whether the goal's current unit is one the user typed rather than an AI
    /// suggestion.
    var isGoalUnitCustom: Bool {
        !selectedUnit.isEmpty && !suggestions.contains { $0.unit == selectedUnit }
    }

    /// The custom unit the reveal's unit menu should still offer: the current
    /// selection when it's custom, otherwise the one the user previously dialed and
    /// switched away from. Nil when no custom unit was ever made.
    var goalMenuCustomUnit: String? {
        isGoalUnitCustom ? selectedUnit : goalCustomUnit
    }

    /// What the AI seams receive in place of the bare name. The default closures
    /// prefix "- Tracker name: ", so the hint rides along as a second bullet line.
    private var nameInstruction: String {
        guard let aiHint else { return name }
        return "\(name)\n- Context: \(aiHint)"
    }

    /// Seam over the AI call so previews/tests supply suggestions without a
    /// network round-trip. Takes the tracker name.
    private let generate: (String) async throws -> GoalAiCompletionListSchema
    /// The name the current `suggestions` were loaded for. Guards the fetch so it
    /// runs once per name and never re-fires on back-navigation.
    private var loadedName: String?

    /// Loading state of the goal-granularity request — fetched on the custom-unit
    /// path only, after the daily target is set.
    private(set) var goalGranularityPhase: Phase = .idle
    /// Seam over the granularity AI call, mirroring `generate`. Takes a built
    /// instruction carrying the tracker name and the custom unit.
    private let generateGranularity: (String) async throws -> GranularityAiCompletionSchema
    /// The name+unit `goalGranularity` was loaded for. Granularity depends on the
    /// unit, so the key combines both: picking a different custom unit re-fetches,
    /// while re-showing the screen for the same one is a no-op.
    private var loadedGranularityKey: String?

    // MARK: - Duration sub-flow

    /// Loading state of the duration emoji auto-completion request.
    private(set) var durationPhase: Phase = .idle
    /// The AI-suggested emoji for the duration tracker. The duration path needs
    /// nothing else from the AI — the wheel logs a fixed h/m/s and goes straight
    /// from naming to the reveal — so this is the lone result of its loading step.
    /// Fetched through the shared `generateEmoji` seam (see the binary sub-flow).
    var durationEmoji = ""
    /// The name `durationEmoji` was loaded for. Guards the fetch so it runs once
    /// per name and never re-fires on back-navigation.
    private var loadedDurationName: String?

    // MARK: - Category sub-flow

    /// Loading state of the category auto-completion request.
    private(set) var categoryPhase: Phase = .idle
    /// The AI-suggested labels, used to *seed* the editable labels screen. The
    /// user can then add, rename, or delete rows; their final list is written
    /// back here on "Next" — so this property is both the seed and the result,
    /// mirroring how `categoryAllowsMultiple` seeds-then-confirms below.
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

    /// Seam over the emoji AI call, mirroring `generate`. Shared by the binary,
    /// date, and duration paths — all three need only an emoji from the AI. Takes
    /// the tracker name.
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
        generate: @escaping (String) async throws -> GoalAiCompletionListSchema = {
            try await GoalAiCompletion().generate(for: "- Tracker name: \($0)")
        },
        generateCategory: @escaping (String) async throws -> CategoryAiCompletionSchema = {
            try await CategoryAiCompletion().generate(for: "- Tracker name: \($0)")
        },
        generateEmoji: @escaping (String) async throws -> EmojiAiCompletionSchema = {
            try await EmojiAiCompletion().generate(for: "- Tracker name: \($0)")
        },
        generateNumber: @escaping (String) async throws -> NumberAiCompletionListSchema = {
            try await NumberAiCompletion().generate(for: "- Tracker name: \($0)")
        },
        generateGranularity: @escaping (String) async throws -> GranularityAiCompletionSchema = {
            try await GranularityAiCompletion().generate(for: $0)
        }
    ) {
        self.generate = generate
        self.generateCategory = generateCategory
        self.generateEmoji = generateEmoji
        self.generateNumber = generateNumber
        self.generateGranularity = generateGranularity
    }

    // MARK: - Seed preload

    /// Runs a seeded (badge-tapped) single-format tracker's *first* AI load up
    /// front — while the empty dashboard still shows its "preparing" glow — so the
    /// flow can open past the loading spinner instead of stacking a second one
    /// behind that glow. Seeds `kind`/`name`/`aiHint` like the flow's seeded
    /// entry would, kicks off the kind's initial completion, and reports whether
    /// it succeeded so the caller can open on the reveal rather than a spinner.
    /// A failure returns `false`; `EmptyDashboardView` never opens the flow in
    /// that case — it shows its own inline retry message instead (see
    /// `EmptyDashboardView.prepareSeed`).
    func preloadSeed(kind: TrackerKind, name: String) async -> Bool {
        self.kind = kind
        self.name = name
        // Setting `name` clears `aiHint` (see its `didSet`), so seed it after —
        // mirroring the flow's seeded `onContinue`, where the chip name doubles
        // as the AI context.
        self.aiHint = name
        switch kind {
        case .number:
            await loadNumberIfNeeded()
            return numberPhase == .loaded
        case .binary:
            await loadBinaryEmojiIfNeeded()
            return binaryPhase == .loaded
        case .date:
            await loadDateEmojiIfNeeded()
            return datePhase == .loaded
        case .duration:
            await loadDurationEmojiIfNeeded()
            return durationPhase == .loaded
        case .choices:
            await loadCategoryIfNeeded()
            return categoryPhase == .loaded
        case .goal:
            await loadSuggestionsIfNeeded()
            return phase == .loaded
        }
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
            let schema = try await generate(nameInstruction)
            suggestions = schema.goals
            // The emoji is list-level, so seed it once here — it stays put as the
            // user switches units, mirroring how `loadNumberIfNeeded` handles
            // `numberEmoji`.
            goalEmoji = schema.emoji
            // Seed the selection with the first suggestion so the unit list and
            // value page have a unit, target and step to show before the user
            // picks — mirroring how `loadNumberIfNeeded` seeds the number path.
            if let first = schema.goals.first {
                selectedUnit = first.unit
                goalValue = first.dailyGoal
                goalGranularity = first.granularity
            }
            loadedName = schema.goals.isEmpty ? nil : name
            phase = schema.goals.isEmpty ? .failed : .loaded
        } catch {
            phase = .failed
        }
    }

    /// Fetches a step natural to a *custom* goal unit (one the AI didn't propose),
    /// keyed on name+unit so it runs once per unit and never re-fires on
    /// back-navigation. The step is non-essential: a failure leaves
    /// `goalGranularity` at its neutral default (the user can still dial it on the
    /// reveal's Step chip), so the loading screen advances either way.
    func loadGoalGranularityIfNeeded(for unit: String) async {
        let key = "\(name)\n\(unit)"
        guard loadedGranularityKey != key || goalGranularityPhase == .failed
        else { return }
        goalGranularityPhase = .loading
        do {
            let schema = try await generateGranularity(
                "- Tracker name: \(nameInstruction)\n- Unit: \(unit)"
            )
            if schema.granularity > 0 { goalGranularity = schema.granularity }
            loadedGranularityKey = key
            goalGranularityPhase = .loaded
        } catch {
            goalGranularityPhase = .failed
        }
    }

    // MARK: - Duration completion

    /// Fetches the duration emoji for `name`, but only when it hasn't already been
    /// loaded for that name (or the previous attempt failed). Re-entrant calls —
    /// e.g. returning to the loading screen — are no-ops, so the AI never
    /// re-triggers on back-navigation. Mirrors `loadBinaryEmojiIfNeeded`.
    func loadDurationEmojiIfNeeded() async {
        guard loadedDurationName != name || durationPhase == .failed else { return }
        durationPhase = .loading
        do {
            let schema = try await generateEmoji(nameInstruction)
            durationEmoji = schema.emoji
            loadedDurationName = name
            durationPhase = .loaded
        } catch {
            durationPhase = .failed
        }
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
            let schema = try await generateEmoji(nameInstruction)
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
            let schema = try await generateEmoji(nameInstruction)
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
            let schema = try await generateNumber(nameInstruction)
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
            let schema = try await generateCategory(nameInstruction)
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
                "\(nameInstruction)\n- Categories: \(labels.joined(separator: ", "))"
            )
            categoryAllowsMultiple = schema.allowsMultipleSelection
            categoryPhase = .loaded
        } catch {
            categoryPhase = .failed
        }
    }

    // MARK: - Goal selection

    /// Commit the unit chosen on the unit list, re-anchoring the suggested target
    /// and step when the unit matches a suggestion; a custom unit has no AI-anchored
    /// target, so clear the value to 0 — the value page then shows a placeholder
    /// rather than the carried-over suggestion, and the user types their own — and
    /// reset the step to neutral `1` so the granularity loading step can fetch one
    /// tuned to it. The emoji is list-level, so it stays put regardless of the unit.
    func chooseUnit(_ unit: String) {
        selectedUnit = unit
        if let match = suggestions.first(where: { $0.unit == unit }) {
            goalValue = match.dailyGoal
            goalGranularity = match.granularity
        } else {
            goalValue = 0
            goalGranularity = 1
        }
    }

    /// Switch the goal's unit from the reveal's unit menu. Picking an AI unit
    /// re-anchors the target and step to that suggestion; picking the user's own
    /// custom unit restores the target and step they had dialed for it. The emoji is
    /// list-level, so it stays put either way. Whichever custom unit we leave is
    /// remembered (with its figures) so the menu keeps offering it — this is what
    /// lets the user switch from their custom unit to an AI one and back without
    /// losing what they entered.
    func selectGoalUnit(_ unit: String) {
        guard unit != selectedUnit else { return }
        // Stash the custom unit we're leaving so it stays in the menu, capturing
        // whatever the user dialed for it (including edits made via the chips).
        if isGoalUnitCustom {
            goalCustomUnit = selectedUnit
            goalCustomValue = goalValue
            goalCustomGranularity = goalGranularity
        }
        selectedUnit = unit
        if let match = suggestions.first(where: { $0.unit == unit }) {
            goalValue = match.dailyGoal
            goalGranularity = match.granularity
        } else {
            // Back to the custom unit: restore the figures stashed for it.
            goalValue = goalCustomValue
            goalGranularity = goalCustomGranularity
        }
    }
}
