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
    var onComplete: () -> Void = {}


    /// Example phrases cycled through, paired index-for-index with `cards`.
    private var texts: [String] {
        [
            String(localized: "Note the **dates** I fill up **gas**"),
            String(localized: "Remind me if I took my **medication**"),
            String(localized: "Help me hit my **goal** of 10 pages a day"),
            String(localized: "Track my mood — happy, neutral, sad, or anxious"),
            String(localized: "Track how tired I feel after **working out**"),
        ]
    }

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
    @State private var showNext = false
    @State private var cycleTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            progressBar
                .padding(.top, 8)

            Spacer(minLength: 0)
            hero
                .padding(.horizontal, -24)
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
    }

    private var hero: some View {
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
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                Capsule()
                    .fill(color)
                    .frame(height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step 4 of 4")
    }

    // MARK: - Next

    private var nextButton: some View {
        Button(action: onComplete) {
            Text("Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
        }
        .controlSize(.extraLarge)
        .buttonStyle(.glassProminent)
        .tint(color)
    }

    /// Only the chart is shown, wrapped in the same bubble as the speech text so
    /// it floats in the same slot just above the mic, without the full card chrome.
    private func cardView(for info: CardInfo) -> some View {
        AnyView(info.chart)
            .frame(height: 100)
            .padding(.horizontal, 24)
            .padding(.vertical, -5)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
//                    .fill(Color(uiColor: .clear))
//                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            )
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
                    showNext = true
                }
            }
        }
    }
}

/// A fake metric chart paired with each example phrase, used purely for the
/// onboarding showcase.
private struct CardInfo {
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
                chart: EventCalendarMiniChart(
                    data: Self.recentDays(60) { [0, 15, 30, 56].contains($0) },
                    color: .orange
                )
            ),
            // "Track if I took my medication"
            CardInfo(
                chart: TrailingCalendarMiniChart(
                    data: Self.recentDays(7) { $0 != 4 },
                    color: .pink
                )
            ),
            // "Help me reach my 10 pages reading a day goal"
            CardInfo(
                chart: LinearGaugeMiniChart(current: 7, goal: 10, color: .blue)
            ),
            // "Track my mood using happy, neutral, sad, or anxious"
            CardInfo(
                chart: DividerBarMiniChart(entries: [
                    .init(category: String(localized: "Happy"), value: 3),
                    .init(category: String(localized: "Neutral"), value: 2),
                    .init(category: String(localized: "Sad"), value: 1),
                    .init(category: String(localized: "Anxious"), value: 1)
                ])
            ),
            // "Keep track of my post workout fatigue"
            CardInfo(
                chart: LineMiniChart(
                    data: [7, 5, 4, 6, 4, 5, 6, 3, 6, 5, 6, 5],
                    color: .teal
                )
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
 
