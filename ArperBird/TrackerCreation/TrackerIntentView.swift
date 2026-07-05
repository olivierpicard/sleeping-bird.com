//
//  TrackerIntentView.swift
//  ArperBird
//
//  Created by Olivier Picard on 05/07/2026.
//

import SwiftUI
#if DEBUG
import FirebaseCore
#endif

/// UI-only mockup of the intent-based creation screen, prompt-first: a free-text
/// "describe it" field on top with quick-fill chips (a fresh per-visit sample of
/// the curated suggestions, one per kind), and the live preview card below as
/// the response, re-shaped by format pills. No AI, no navigation, no
/// persistence — built to evaluate the design before committing.
struct TrackerIntentView: View {
    @State private var suggestions: [IntentSuggestion]
    @State private var placeholder: Metric
    @State private var selected: IntentSuggestion?
    @State private var formatIndex = 0
    @State private var isLoading = false
    @State private var isFailed = false
    @State private var text = ""
    @State private var promptIndex = 0
    @FocusState private var isFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// AI seam: interprets the free-text field into a titled intent + formats.
    /// Injected so previews drive the fake without a network round-trip.
    private let generateIntent: (String) async throws -> IntentCompletion

    /// Rotating placeholder examples, each completing the fixed "Track" prefix
    /// — and each quietly demoing a different answer shape (number, duration,
    /// yes/no, choices, goal, date).
    private static let examplePrompts: [LocalizedStringKey] = [
        "how many coffees I drink",
        "time spent reading",
        "if I stretched today",
        "my mood today",
        "8 glasses of water a day",
        "when I last watered the plants",
    ]

    init(
        generateIntent: @escaping (String) async throws -> IntentCompletion = {
            try await IntentAiCompletion().generate(for: $0)
        }
    ) {
        self.generateIntent = generateIntent
        _suggestions = State(initialValue: Self.makeSuggestions())
        _placeholder = State(
            initialValue: Metric(
                from: MetricSchema.Fake.number(
                    title: String(localized: "Your tracker name"),
                    emoji: "🫥",
                    goal: nil,
                    chart: .line
                ),
                color: .gray,
                data: Self.calmPlaceholderData()
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
                .padding(.top, 30)

            // Quick-fill examples for the field: a tap fills the prompt, then
            // the card below resolves — teaching the field→card causality.
            BadgesStackView(
                badges: suggestions.map(\.chipLabel),
                innerPadding: 5,
                borderThickness: 0.5,
                alignment: .center,
                maxRows: 2,
                onTap: { index in resolve(suggestions[index]) }
            )
            .font(.footnote)
            .padding(.horizontal)
            .padding(.top, 14)

            // The response zone, anchored to the prompt cluster above: a label
            // that names the zone (and explains the ghost card), the card, and
            // its format pills directly beneath it. The remaining slack lives
            // between the pills and the CTA.
            Text(responseZoneLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 40)

            Group {
                if isFailed {
                    failureCard
                } else {
                    previewCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

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
            .disabled(selected == nil || isLoading || isFailed)
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture { isFieldFocused = false }
        .navigationTitle("Add a tracker")
        .navigationSubtitle("What do you want to track ?")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Subviews

    private var responseZoneLabel: LocalizedStringKey {
        if isLoading { return "Creating your tracker…" }
        if isFailed { return "Hmm, that didn't go through" }
        return selected == nil
            ? "Your tracker will appear here"
            : "You, three weeks from now"
    }
 
    private var previewCard: some View {
        MetricView(
            mainColor: mainColor,
            header: {
                MetricHeaderTextView(
                    title: displayedMetric.name,
                    emoji: displayedMetric.emoji,
                    mainColor: mainColor,
                )
            },
            chart: MiniChartFactory.make(from: displayedMetric)
        )
        // The ghost is a promise, not a dead widget — keep it quiet.
        .opacity(selected == nil || isLoading ? 0.55 : 1)
        .redacted(reason: isLoading ? .placeholder : [])
        .animation(.snappy, value: isLoading)
    }

    /// Dedicated failure state for the card slot: replaces the preview card in
    /// the exact same footprint (a hidden preview card reserves the frame) so
    /// the response zone never jumps. Muted on purpose — a hiccup, not a loss.
    private var failureCard: some View {
        previewCard
            .hidden()
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    Text("Couldn't reach the AI")
                        .font(.headline)
                    Text("Check your connection and try again")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: { resolveCustom() }) {
                        Label("Try again", systemImage: "arrow.clockwise")
                            .font(.footnote.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.gray)
                    .padding(.top, 8)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Couldn't reach the AI. Check your connection and try again.")
    }

    /// One pill per way this suggestion can be logged; tapping re-shapes the
    /// preview instantly (in the real flow this is a local morph, no AI).
    private var formatPills: some View {
        HStack(spacing: 8) {
            if let selected, !isLoading, !isFailed {
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
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .focused($isFieldFocused)
                .submitLabel(.done)
                .onSubmit { resolveCustom() }
                .accessibilityLabel("Describe what you want to track")
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        HStack(spacing: 4) {
                            Text("Track")
                            Text(Self.examplePrompts[promptIndex])
                                .id(promptIndex)
                                .transition(
                                    reduceMotion
                                        ? .opacity : .push(from: .bottom)
                                )
                        }
                        .foregroundStyle(Color(.placeholderText))
                        .allowsHitTesting(false)
                    }
                }
                .clipped()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemFill))
        )
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard text.isEmpty, !isFieldFocused else { continue }
                withAnimation(.snappy) {
                    promptIndex = (promptIndex + 1) % Self.examplePrompts.count
                }
            }
        }
    }

    // MARK: - Fake resolution (stands in for the AI classify call)

    private func resolve(_ suggestion: IntentSuggestion) {
        text = suggestion.name
        isFailed = false
        isLoading = true
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            formatIndex = 0
            selected = suggestion
            isLoading = false
        }
    }

    /// Free-text resolution: hands the typed prompt to the AI, which returns a
    /// title, emoji, and the formats that best fit it. On failure the card slot
    /// shows the dedicated failure card; the prompt stays in the field, so
    /// "Try again" (or return) re-submits it.
    private func resolveCustom() {
        let name = text.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isFieldFocused = false
        isFailed = false
        isLoading = true
        Task {
            do {
                let completion = try await generateIntent(name)
                formatIndex = 0
                selected = intentSuggestion(from: completion)
            } catch {
                selected = nil
                isFailed = true
            }
            isLoading = false
        }
    }

    /// Turns the AI's interpreted intent into the local `IntentSuggestion` the
    /// preview card and format pills already render.
    private func intentSuggestion(from completion: IntentCompletion) -> IntentSuggestion {
        let color = Self.color(for: completion.formats.first?.kind ?? .number)
        return IntentSuggestion(
            name: completion.title,
            emoji: completion.emoji,
            chipLabel: "\(completion.title) \(completion.emoji)",
            color: color,
            formats: completion.formats.map {
                Self.intentFormat(
                    for: $0,
                    name: completion.title,
                    emoji: completion.emoji,
                    color: color
                )
            }
        )
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
        /// Short chip text — may be shorter than `name` (e.g. "Practice" vs
        /// "Music Practice").
        let chipLabel: String
        let color: Color
        let formats: [IntentFormat]
    }

    /// A calm, slow swell for the ghost card — deliberately unlike real data so
    /// the placeholder reads as "awaiting", not as a noisy dead widget.
    private static func calmPlaceholderData(days: Int = 22) -> [DataPoint] {
        let calendar = Calendar.current
        return (0..<days).map { day in
            let date = calendar.date(byAdding: .day, value: -day, to: .now) ?? .now
            let phase =  Double.pi
            let value = 50 + 8 * sin(Double(day) / 2.5 + phase)
            return .number(date, value)
        }
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

    /// One random curated example per kind (drawn from the type-picker's
    /// pools), in shuffled order — a fresh set each visit that always spans
    /// every tracker kind.
    private static func makeSuggestions() -> [IntentSuggestion] {
        TrackerKind.allCases
            .compactMap { TrackerSuggestion.examples(for: $0).randomElement() }
            .shuffled()
            .map(intentSuggestion(from:))
    }

    /// Card tint per kind, standing in for the color the AI would pick.
    private static func color(for kind: TrackerKind) -> Color {
        switch kind {
        case .number: .teal
        case .duration: .purple
        case .choices: .yellow
        case .binary: .green
        case .goal: .orange
        case .date: .pink
        }
    }

    /// Fake resolution for a curated suggestion: the formats the AI would
    /// offer for its kind, seeded with the suggestion's name and emoji.
    private static func intentSuggestion(
        from suggestion: TrackerSuggestion
    ) -> IntentSuggestion {
        let color = color(for: suggestion.kind)
        return IntentSuggestion(
            name: suggestion.localizedName,
            emoji: suggestion.emoji,
            chipLabel: suggestion.chipText,
            color: color,
            formats: formats(
                for: suggestion.kind,
                name: suggestion.localizedName,
                emoji: suggestion.emoji,
                color: color
            )
        )
    }

    /// The formats offered per curated (chip) kind — a small combo of the ways
    /// that kind is naturally logged.
    private static func formats(
        for kind: TrackerKind,
        name: String,
        emoji: String,
        color: Color
    ) -> [IntentFormat] {
        let types: [IntentFormatType] = switch kind {
        case .duration: [.duration, .binary]
        case .binary: [.binary]
        case .choices: [.choices]
        case .date: [.date]
        case .goal: [.goal, .number]
        case .number: [.number, .binary]
        }
        return types.map {
            intentFormat(for: $0, name: name, emoji: emoji, color: color)
        }
    }

    /// Builds a single pill + preview card for one logging format. Shared by
    /// the curated chip path (`formats(for:)`) and the AI free-text path
    /// (`intentSuggestion(from:)`).
    private static func intentFormat(
        for type: IntentFormatType,
        name: String,
        emoji: String,
        color: Color
    ) -> IntentFormat {
        switch type {
        case .duration:
            IntentFormat(
                label: String(localized: "Time spent"),
                icon: "clock",
                metric: metric(
                    MetricSchema.Fake.duration(
                        title: name,
                        emoji: emoji,
                        chart: .bar
                    ),
                    color: color,
                    days: 40
                )
            )
        case .binary:
            IntentFormat(
                label: String(localized: "Yes / No"),
                icon: "checkmark.circle",
                metric: metric(
                    MetricSchema.Fake.binary(
                        title: name,
                        emoji: emoji,
                        chart: .calendar
                    ),
                    color: color
                )
            )
        case .number:
            IntentFormat(
                label: String(localized: "A number"),
                icon: "number",
                metric: metric(
                    MetricSchema.Fake.number(
                        title: name,
                        emoji: emoji,
                        goal: nil,
                        chart: .bar
                    ),
                    color: color,
                    days: 40
                )
            )
        case .goal:
            IntentFormat(
                label: String(localized: "Daily goal"),
                icon: "target",
                metric: metric(
                    MetricSchema.Fake.number(
                        title: name,
                        emoji: emoji,
                        min: 0,
                        max: 10,
                        granularity: 1,
                        goal: 8,
                        chart: .dailyGauge
                    ),
                    color: color
                )
            )
        case .choices:
            IntentFormat(
                label: String(localized: "Pick from a list"),
                icon: "list.bullet",
                metric: metric(
                    MetricSchema.Fake.categorySingle(
                        title: name,
                        emoji: emoji,
                        chart: .pie
                    ),
                    color: color
                )
            )
        case .date:
            IntentFormat(
                label: String(localized: "A date"),
                icon: "calendar",
                metric: metric(
                    MetricSchema.Fake.datetime(
                        title: name,
                        emoji: emoji,
                        chart: .calendar
                    ),
                    color: color
                )
            )
        }
    }

}

private extension IntentFormatType {
    /// The tracker kind this format belongs to — used to tint the card.
    var kind: TrackerKind {
        switch self {
        case .number: .number
        case .duration: .duration
        case .binary: .binary
        case .goal: .goal
        case .choices: .choices
        case .date: .date
        }
    }
}

/// Every submit fails after the usual "thinking" beat — type anything and hit
/// return to land on the failure card.
#Preview("Failure") {
    NavigationStack {
        TrackerIntentView(
            generateIntent: { _ in
                try await Task.sleep(for: .seconds(0.7))
                throw URLError(.notConnectedToInternet)
            }
        )
    }
    .environment(\.locale, Locale(identifier: "en_US"))
}

#Preview("Fake AI") {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerIntentView(
                generateIntent: { try await IntentAiCompletion().generateFake(for: $0) }
            )
        }
        .environment(\.locale, Locale(identifier: "en_US"))
    }
    .presentationDetents([.large])
}

#if DEBUG
/// Drives the real Firebase AI completion on submit. Configures Firebase
/// itself since the AppDelegate doesn't run in previews.
#Preview("Real AI") {
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    return NavigationStack {
        TrackerIntentView()
    }
    .environment(\.locale, Locale(identifier: "en_US"))
}
#endif
