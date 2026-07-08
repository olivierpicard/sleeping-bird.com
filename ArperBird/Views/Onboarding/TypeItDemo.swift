//
//  TypeItDemo.swift
//  ArperBird
//
//  Created by Olivier Picard on 08/07/2026.
//

import SwiftUI

/// Onboarding hero animation — the *typing* rehearsal that replaces the
/// voice-themed `GuidedAnimation`. Each cycle:
///   1. A prompt field "types" itself out word by word while a sparkle pulses,
///      as if the user were describing what they want to track.
///   2. The field settles once the last word lands; the caret keeps blinking.
///   3. The field morphs into the matching tracker card (a real `MetricView`),
///      the card frame springing out of the field's own frame.
///   4. The card lingers, then the next cycle's field fades back in.
///
/// The field↔card morph is a `matchedGeometryEffect`, so the card literally
/// grows out of the field — a rehearsal of the exact gesture the user performs
/// seconds later in `TrackerIntentView`. The sequence loops forever.
struct TypeItDemo: View {
    var color: Color = .indigo
    var onComplete: () -> Void = {}

    /// Delay between each revealed word.
    private let wordInterval: TimeInterval = 0.3
    /// Extra time for the field to settle once the last word lands.
    private let writingBuffer: TimeInterval = 0.4
    /// How long the finished field settles before morphing into a card.
    private let fieldSettle: TimeInterval = 0.9
    /// How long the card lingers before the cycle fades out.
    private let cardSettle: TimeInterval = 2.2

    private enum Stage { case typing, card }

    @State private var index = 0
    @State private var stage: Stage = .typing
    @State private var isTyping = true
    @State private var showNext = false
    @State private var cycleTask: Task<Void, Never>?
    @Namespace private var morph
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            headline
                .padding(.top, 24)
                .padding(.horizontal, 8)

            Spacer(minLength: 0)
            hero
            cycleDots
                .padding(.top, 24)
            Spacer(minLength: 0)

            if showNext {
                nextButton
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            EmptyDashboardBackground(intensity: 0.3)
                .ignoresSafeArea()
        }
        .onAppear { startCycle() }
        .onDisappear { cycleTask?.cancel() }
        .trackScreen("Onboarding_TypeItDemo")
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: 6) {
            Text("Just type what you want to track.")
                .font(.title2.weight(.semibold))
            Text("We'll build the tracker for you.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Hero (the field ↔ card morph)

    private var hero: some View {
        ZStack {
            switch stage {
            case .typing:
                TypingPromptField(
                    prompt: trackers[index].prompt,
                    wordInterval: wordInterval,
                    isTyping: isTyping,
                    accent: color
                )
                .id("field-\(index)")
                .matchedGeometryEffect(id: "shell", in: morph)
                .transition(.opacity)

            case .card:
                cardView(for: trackers[index])
                    .matchedGeometryEffect(id: "shell", in: morph)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .center)
    }

    /// The morph target: a real dashboard card, so the user sees the actual
    /// product materialize out of the field they just watched fill in. The
    /// header drops its "+" button (`showAddButton: false`) — and with it the
    /// `AddEntryTip` popover — since this is a non-interactive showcase, not a
    /// live card the user can log into.
    private func cardView(for tracker: DemoTracker) -> some View {
        MetricView(
            mainColor: tracker.color,
            header: {
                MetricHeaderValueView(
                    title: tracker.title,
                    emoji: tracker.emoji,
                    value: tracker.value,
                    mainColor: tracker.color,
                    showAddButton: false
                )
            },
            chart: tracker.chart
        )
        .allowsHitTesting(false)
    }

    // MARK: - Cycle dots

    private var cycleDots: some View {
        HStack(spacing: 8) {
            ForEach(trackers.indices, id: \.self) { i in
                Circle()
                    .fill(i == index ? color : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .animation(.easeInOut, value: index)
        .accessibilityHidden(true)
    }

    // MARK: - CTA

    private var nextButton: some View {
        Button(action: onComplete) {
            Text("Create my first tracker")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
        }
        .controlSize(.extraLarge)
        .buttonStyle(.glassProminent)
        .tint(color)
    }

    // MARK: - Cycle engine

    /// Approximate time the field needs to finish revealing `prompt`.
    private func writingDuration(for prompt: String) -> TimeInterval {
        let wordCount = prompt.split(separator: " ").count
        return Double(wordCount) * wordInterval + writingBuffer
    }

    private func startCycle() {
        cycleTask?.cancel()
        cycleTask = Task { @MainActor in
            while !Task.isCancelled {
                // 1. Field types itself out while the sparkle pulses.
                try? await Task.sleep(for: .seconds(writingDuration(for: trackers[index].prompt)))
                guard !Task.isCancelled else { return }

                // 2. Typing stops; the field settles (caret keeps blinking).
                isTyping = false
                try? await Task.sleep(for: .seconds(fieldSettle))
                guard !Task.isCancelled else { return }

                // 3. Field morphs into the card, which settles.
                let morphAnimation: Animation = reduceMotion
                    ? .easeInOut(duration: 0.5)
                    : .spring(response: 0.65, dampingFraction: 0.85)
                withAnimation(morphAnimation) {
                    stage = .card
                }
                try? await Task.sleep(for: .seconds(cardSettle))
                guard !Task.isCancelled else { return }

                // 4. Card fades out as the next cycle's field fades in.
                withAnimation(.easeInOut(duration: 0.5)) {
                    index = (index + 1) % trackers.count
                    stage = .typing
                    isTyping = true
                    showNext = true
                }
            }
        }
    }
}

// MARK: - Typing prompt field

/// A field styled like the real `TrackerIntentView` input, that reveals its
/// prompt word by word — a pulsing sparkle stands in for the AI, and a blinking
/// caret sits at the reveal head. Restarts its reveal whenever `.id(prompt)`
/// changes.
private struct TypingPromptField: View {
    let prompt: String
    var wordInterval: TimeInterval = 0.3
    var isTyping: Bool = true
    var accent: Color = .indigo

    @State private var revealedWordCount = 0
    @State private var caretVisible = true
    @State private var revealTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var words: [Substring] {
        prompt.split(separator: " ")
    }

    private var revealedText: String {
        words.prefix(revealedWordCount).joined(separator: " ")
    }

    /// Typing isn't done until every word is on screen.
    private var isRevealing: Bool {
        isTyping && revealedWordCount < words.count
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.line")
                .foregroundStyle(accent)
                .symbolEffect(.pulse, options: .repeating, isActive: isRevealing && !reduceMotion)

            HStack(spacing: 2) {
                Text(revealedText)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                caret
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .accessibilityElement()
        .accessibilityLabel(Text(prompt))
        .onAppear { startReveal() }
        .onDisappear { revealTask?.cancel() }
    }

    private var caret: some View {
        Capsule()
            .fill(accent)
            .frame(width: 2, height: 20)
            .opacity(caretVisible ? 1 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.5).repeatForever(),
                value: caretVisible
            )
            .onAppear { caretVisible = false }
    }

    private func startReveal() {
        revealedWordCount = 0
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            for i in words.indices {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(wordInterval))
                guard !Task.isCancelled else { return }
                revealedWordCount = i + 1
            }
        }
    }
}

// MARK: - Demo data

/// One example tracker, pairing the typed prompt with the card it becomes —
/// used purely for the onboarding showcase.
private struct DemoTracker {
    let prompt: String
    let emoji: String
    let title: String
    let value: String
    let chart: any MiniChart
    let color: Color
}

extension TypeItDemo {
    private static func recentDays(_ count: Int, picking keep: (Int) -> Bool) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<count).compactMap { offset in
            keep(offset) ? calendar.date(byAdding: .day, value: -offset, to: today) : nil
        }
    }

    /// The trackers cycled through, each demoing a different answer shape. Prompts
    /// are terse — the way people actually type, not dictate.
    fileprivate var trackers: [DemoTracker] {
        [
            // A plain number.
            DemoTracker(
                prompt: String(localized: "Coffee intake"),
                emoji: "☕️",
                title: String(localized: "Coffee"),
                value: String(localized: "3 cups"),
                chart: BarMiniChart(
                    data: [2, 4, 3, 5, 2, 4, 3, 4, 2, 5, 3, 4],
                    color: .teal
                ),
                color: .teal
            ),
            // A duration.
            DemoTracker(
                prompt: String(localized: "Time spent reading"),
                emoji: "📖",
                title: String(localized: "Reading"),
                value: String(localized: "45m"),
                chart: BarMiniChart(
                    data: [20, 45, 30, 60, 15, 50, 40, 35, 25, 55, 45, 30],
                    color: .purple
                ),
                color: .purple
            ),
            // A yes/no habit.
            DemoTracker(
                prompt: String(localized: "Took my medication"),
                emoji: "💊",
                title: String(localized: "Medication"),
                value: String(localized: "6-day streak"),
                chart: TrailingCalendarMiniChart(
                    data: Self.recentDays(7) { $0 != 4 },
                    color: .pink
                ),
                color: .pink
            ),
            // A daily goal.
            DemoTracker(
                prompt: String(localized: "Read 10 pages a day"),
                emoji: "📚",
                title: String(localized: "Pages read"),
                value: String(localized: "7 / 10"),
                chart: LinearGaugeMiniChart(current: 7, goal: 10, color: .orange),
                color: .orange
            ),
            // A pick-from-a-list mood.
            DemoTracker(
                prompt: String(localized: "Mood today"),
                emoji: "😊",
                title: String(localized: "Mood"),
                value: String(localized: "Happy"),
                chart: DividerBarMiniChart(entries: [
                    .init(category: String(localized: "Happy"), value: 3),
                    .init(category: String(localized: "Neutral"), value: 2),
                    .init(category: String(localized: "Sad"), value: 1),
                    .init(category: String(localized: "Anxious"), value: 1)
                ]),
                color: .yellow
            ),
            // A date logged on the calendar.
            DemoTracker(
                prompt: String(localized: "Gas fill-up dates"),
                emoji: "⛽️",
                title: String(localized: "Gas fill-ups"),
                value: String(localized: "4 this month"),
                chart: EventCalendarMiniChart(
                    data: Self.recentDays(60) { [0, 15, 30, 56].contains($0) },
                    color: .indigo
                ),
                color: .indigo
            )
        ]
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        TypeItDemo()
    }
}
