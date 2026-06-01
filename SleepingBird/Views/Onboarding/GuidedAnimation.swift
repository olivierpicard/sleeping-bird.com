//
//  GuideAnimation.swift
//  SleepingBird
//
//  Created by Olivier Picard on 01/06/2026.
//

import SwiftUI

/// Onboarding hero animation. Each cycle:
///   1. A speech bubble "types" itself out word by word while the microphone waves.
///   2. The mic stops waving once the bubble finishes writing; the bubble settles.
///   3. The bubble slides up and is replaced by the matching metric card, which settles.
///   4. The card fades out as the next cycle's bubble fades in.
///
/// The slide-up is the transition between bubble and card; the fade is the
/// transition between cycles. The sequence loops forever.
struct GuidedAnimation: View {
    var color: Color = .indigo

    /// Example phrases cycled through, paired index-for-index with `cards`.
    private let texts = [
        "Note the dates I put gas in my car",
        "Keep track of my post workout fatigue",
        "Track if I took my medication",
        "Help me reach my 10 pages reading a day goal",
        "Track my mood using happy, neutral, sad, or anxious"
    ]

    /// Delay between each revealed word.
    private let wordInterval: TimeInterval = 0.3
    /// Extra time for the bubble's spring to settle once the last word lands.
    private let writingBuffer: TimeInterval = 0.4
    /// How long the finished bubble settles before sliding up into a card.
    private let bubbleSettle: TimeInterval = 0.9
    /// How long the card lingers before the cycle fades out.
    private let cardSettle: TimeInterval = 2.2

    private enum Stage { case bubble, card }

    @State private var index = 0
    @State private var stage: Stage = .bubble
    @State private var micActive = true
    @State private var cycleTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            MicWavesAnimation(color: color, isActive: micActive)
                .padding(.vertical, 20)
            ZStack {
                switch stage {
                case .bubble:
                    SpeechAnimation(text: texts[index], wordInterval: wordInterval)
                        .id("bubble-\(index)")
                        .transition(bubbleTransition)
                    
                case .card:
                    cardView(for: cards[index])
                        .id("card-\(index)")
                        .transition(cardTransition)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .bottom)
            .padding(.horizontal, 24)
            .clipped()
            .offset(y: -10)
        }
        .onAppear { startCycle() }
        .onDisappear { cycleTask?.cancel() }
    }

    /// The full `MetricView` is shrunk down so the card floats in the same slot
    /// as the speech bubble, just above the mic. Scaling from the bottom keeps
    /// its baseline aligned with the bubble it rises out of.
    private func cardView(for info: CardInfo) -> some View {
        MetricView(
            title: info.title,
            emoji: info.emoji,
            value: info.value,
            mainColor: info.color,
            onAddTapped: {},
            chart: info.chart
        )
        .frame(width: 420)
        .scaleEffect(0.8, anchor: .top)
    }

    /// Bubble fades in at the start of a cycle and slides up out when it becomes a card.
    private var bubbleTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: .offset(y: -50).combined(with: .opacity)
        )
    }

    /// Card slides up into place from the bubble and fades out at the end of a cycle.
    private var cardTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 60).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Approximate time `SpeechAnimation` needs to finish revealing `text`.
    private func writingDuration(for text: String) -> TimeInterval {
        let wordCount = text.split(separator: " ").count
        return Double(wordCount) * wordInterval + writingBuffer
    }

    private func startCycle() {
        cycleTask?.cancel()
        cycleTask = Task { @MainActor in
            while !Task.isCancelled {
                // 1. Bubble types itself out while the mic waves.
                try? await Task.sleep(for: .seconds(writingDuration(for: texts[index])))
                guard !Task.isCancelled else { return }

                // 2. Mic stops waving; the bubble settles.
                micActive = false
                try? await Task.sleep(for: .seconds(bubbleSettle))
                guard !Task.isCancelled else { return }

                // 3. Bubble slides up and is replaced by the card, which settles.
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    stage = .card
                }
                try? await Task.sleep(for: .seconds(cardSettle))
                guard !Task.isCancelled else { return }

                // 4. Card fades out as the next cycle's bubble fades in.
                withAnimation(.easeInOut(duration: 0.5)) {
                    index = (index + 1) % texts.count
                    stage = .bubble
                    micActive = true
                }
            }
        }
    }
}

/// A fake metric card paired with each example phrase, used purely for the
/// onboarding showcase.
private struct CardInfo {
    let title: String
    let emoji: String
    let value: String
    let color: Color
    let chart: any MiniChart
}

extension GuidedAnimation {
    private static func recentDays(_ count: Int, picking keep: (Int) -> Bool) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<count).compactMap { offset in
            keep(offset) ? calendar.date(byAdding: .day, value: -offset, to: today) : nil
        }
    }

    /// Fake cards shown after each phrase, paired index-for-index with `texts`.
    fileprivate var cards: [CardInfo] {
        [
            // "Note the dates I put gas in my car"
            CardInfo(
                title: "Gas Fill-Ups",
                emoji: "⛽️",
                value: "Jun 1",
                color: .orange,
                chart: EventCalendarMiniChart(
                    data: Self.recentDays(40) { [2, 9, 18, 27].contains($0) },
                    color: .orange
                )
            ),
            // "Keep track of my post workout fatigue"
            CardInfo(
                title: "Workout Fatigue",
                emoji: "😮‍💨",
                value: "Medium",
                color: .teal,
                chart: LineMiniChart(
                    data: [4, 6, 5, 7, 3, 5, 6, 4, 7, 5, 6, 5],
                    color: .teal
                )
            ),
            // "Track if I took my medication"
            CardInfo(
                title: "Medication",
                emoji: "💊",
                value: "Taken",
                color: .pink,
                chart: TrailingCalendarMiniChart(
                    data: Self.recentDays(7) { $0 != 4 },
                    color: .pink
                )
            ),
            // "Help me reach my 10 pages reading a day goal"
            CardInfo(
                title: "Pages Read",
                emoji: "📖",
                value: "7 / 10",
                color: .blue,
                chart: LinearGaugeMiniChart(current: 7, goal: 10, color: .blue)
            ),
            // "Track my mood using happy, neutral, sad, or anxious"
            CardInfo(
                title: "Mood",
                emoji: "🙂",
                value: "Happy",
                color: .purple,
                chart: StackedBarMiniChart(entries: [
                    .init(timeIndex: 0, category: "Happy", value: 1),
                    .init(timeIndex: 1, category: "Neutral", value: 1),
                    .init(timeIndex: 2, category: "Anxious", value: 1),
                    .init(timeIndex: 3, category: "Happy", value: 1),
                    .init(timeIndex: 4, category: "Sad", value: 1),
                    .init(timeIndex: 5, category: "Neutral", value: 1),
                    .init(timeIndex: 6, category: "Happy", value: 1)
                ])
            )
        ]
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        GuidedAnimation()
    }
}
