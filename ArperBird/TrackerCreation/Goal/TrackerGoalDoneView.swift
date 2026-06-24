//
//  TrackerGoalDoneView.swift
//  ArperBird
//
//  Created by Olivier Picard on 24/06/2026.
//

import SwiftUI

/// The closing beat of the goal sub-flow, shown after `TrackerGoalValueView`.
/// An implicit congratulation: the fully assembled card drops in under a short
/// headline with a sparkle burst, so the reward is *seeing the thing they just
/// built*. The gauge reads an honest 0% — the card has no entries yet — which
/// doubles as a gentle nudge toward adding the first value.
struct TrackerGoalDoneView: View {
    let name: String
    let emoji: String
    let unit: String
    /// The daily target chosen on `TrackerGoalValueView`. Anchors the gauge goal
    /// and the "per day" recap line.
    let goal: Double
    let color: Color
    var onDone: () -> Void

    /// Drives the entrance: the card springs up from small and translucent once
    /// the view appears.
    @State private var hasAppeared = false
    /// A one-shot color bloom around the card that flashes as it lands, then
    /// settles to the resting glow.
    @State private var glow = false

    init(
        name: String = "Drink more water",
        emoji: String = "💧",
        unit: String = "glasses",
        goal: Double = 8,
        color: Color = .accent,
        onDone: @escaping () -> Void = {}
    ) {
        self.name = name
        self.emoji = emoji
        self.unit = unit
        self.goal = goal
        self.color = color
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            headline

            card
                .padding(.horizontal)
                // A bloom of the tracker's color behind the card that flashes
                // bright as it lands, then settles — the punch of the reveal.
                .shadow(
                    color: color.opacity(glow ? 0.9 : 0.35),
                    radius: glow ? 36 : 10
                )
                // Launch small from below and overshoot into place so the card
                // really *arrives* rather than fading in.
                .scaleEffect(hasAppeared ? 1 : 0.4)
                .offset(y: hasAppeared ? 0 : 70)
                .opacity(hasAppeared ? 1 : 0)

            recap

            Spacer()
            Spacer()

            Button(action: onDone) {
                Text("Add to dashboard")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .tint(color)
            .padding()
        }
        // A scattered sparkle burst behind everything, sized to the celebration.
        .background(alignment: .top) { SparkleBurst(color: color, active: hasAppeared) }
        // A success cue the moment the card lands.
        .sensoryFeedback(.success, trigger: hasAppeared)
        .onAppear {
            // A loose spring (low damping) overshoots, giving the card a bouncy
            // "pop" as it settles.
            withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) {
                hasAppeared = true
            }
            // Bloom the glow just as the card reaches its mark, then let it ease
            // back down to the resting state.
            Task {
                try? await Task.sleep(for: .seconds(0.35))
                withAnimation(.easeOut(duration: 0.25)) { glow = true }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeInOut(duration: 0.7)) { glow = false }
            }
        }
        .trackScreen("ManualTrackerCreationGoalDone")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: 6) {
            Text("🎉")
                .font(.system(size: 48))
                .scaleEffect(hasAppeared ? 1 : 0.4)

            Text("You're all set!")
                .font(.title.weight(.bold))

            Text("Your tracker is ready to go.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }

    // MARK: - Card

    /// The real card chrome, with the daily gauge the user just configured —
    /// shown at 0% because there are no entries yet.
    private var card: some View {
        MetricView(
            mainColor: color,
            header: {
                MetricHeaderTextView(
                    title: name,
                    emoji: emoji,
                    value: "0 \(unit)",
                    mainColor: color,
                    showAddButton: false
                )
            },
            chart: {
                AnyView(
                    LinearGaugeMiniChart(current: 0, goal: goal, color: color)
                        .padding(.horizontal)
                )
            }
        )
    }

    // MARK: - Recap

    private var recap: some View {
        Text("Goal: \(goal.formatted(.number)) \(unit) per day")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Sparkle burst

/// A lightweight, dependency-free confetti substitute: a handful of sparkle
/// glyphs scattered around the headline that fade and drift in when `active`
/// flips true. Deliberately modest — enough to feel celebratory without a
/// physics engine.
private struct SparkleBurst: View {
    let color: Color
    let active: Bool

    private struct Spark: Identifiable {
        let id = UUID()
        let x: CGFloat        // 0...1 of the width
        let y: CGFloat        // 0...1 of the height
        let size: CGFloat
        let symbol: String
        let delay: Double
    }

    private let sparks: [Spark] = [
        .init(x: 0.12, y: 0.10, size: 22, symbol: "sparkle", delay: 0.05),
        .init(x: 0.86, y: 0.08, size: 28, symbol: "sparkles", delay: 0.18),
        .init(x: 0.22, y: 0.32, size: 16, symbol: "sparkle", delay: 0.30),
        .init(x: 0.78, y: 0.30, size: 20, symbol: "sparkle", delay: 0.12),
        .init(x: 0.50, y: 0.04, size: 18, symbol: "sparkles", delay: 0.24),
        .init(x: 0.92, y: 0.40, size: 14, symbol: "sparkle", delay: 0.36),
        .init(x: 0.08, y: 0.42, size: 18, symbol: "sparkle", delay: 0.42),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(sparks) { spark in
                Image(systemName: spark.symbol)
                    .font(.system(size: spark.size))
                    .foregroundStyle(color.gradient)
                    .position(
                        x: spark.x * geo.size.width,
                        y: spark.y * geo.size.height
                    )
                    .scaleEffect(active ? 1 : 0.2)
                    .opacity(active ? 0.9 : 0)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.55)
                            .delay(spark.delay),
                        value: active
                    )
            }
        }
        .allowsHitTesting(false)
        // Confine the burst to the upper celebration zone.
        .frame(height: 320)
    }
}

#Preview("Small count") {
    NavigationStack {
        TrackerGoalDoneView(
            name: "Drink more water",
            emoji: "💧",
            unit: "glasses",
            goal: 8,
            color: .accent
        )
    }
}

#Preview("Large value") {
    NavigationStack {
        TrackerGoalDoneView(
            name: "Walk more",
            emoji: "👟",
            unit: "steps",
            goal: 8000,
            color: .blue
        )
    }
}
