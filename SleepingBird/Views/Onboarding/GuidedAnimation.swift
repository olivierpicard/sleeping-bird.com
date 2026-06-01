//
//  GuideAnimation.swift
//  SleepingBird
//
//  Created by Olivier Picard on 01/06/2026.
//

import SwiftUI

/// OnboardiKeep g hero animation: a speech bubble above a continuously waving
/// microphone. Each text "types" itself out word by word, pauses to be read,
/// then slides up and fades out as the next one rises in from below. The
/// sequence loops forever.
struct GuidedAnimation: View {
    var color: Color = .indigo

    /// Example phrases cycled through, in order.
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
    /// How long a fully written phrase lingers before sliding away.
    private let readPause: TimeInterval = 1.6

    @State private var index = 0
    @State private var cycleTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            MicWavesAnimation(color: color, isActive: true)
                .padding(.vertical, 20)
            ZStack {
                SpeechAnimation(text: texts[index], wordInterval: wordInterval)
                    .id(index)
                    .transition(.asymmetric(
                        insertion: AnyTransition(SlideFadeTransition(edge: .bottom)),
                        removal: AnyTransition(SlideFadeTransition(edge: .top))
                    ))
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .bottom)
            .padding(.horizontal, 24)
            .clipped()
        }
        .onAppear { startCycle() }
        .onDisappear { cycleTask?.cancel() }
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
                let onScreen = writingDuration(for: texts[index]) + readPause
                try? await Task.sleep(for: .seconds(onScreen))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    index = (index + 1) % texts.count
                }
            }
        }
    }
}

/// Slides the bubble in/out from `edge` while fading. The opacity runs on a
/// quicker curve than the slide so the bubble is fully transparent well before
/// it reaches the clipped edge of the layout — no hard edge ever shows.
private struct SlideFadeTransition: Transition {
    var edge: Edge

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0, )
            .animation(.easeOut(duration: 0.4), value: phase.isIdentity)
            .offset(y: offset(for: phase))
    }

    private func offset(for phase: TransitionPhase) -> CGFloat {
        guard !phase.isIdentity else { return 0 }
        return edge == .top ? -60 : 60
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        GuidedAnimation()
    }
}
