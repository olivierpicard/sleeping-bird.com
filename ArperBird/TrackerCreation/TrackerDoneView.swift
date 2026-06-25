//
//  TrackerDoneView.swift
//  ArperBird
//
//  Created by Olivier Picard on 24/06/2026.
//

import SwiftUI

/// The closing beat shared by every tracker-creation path. An implicit
/// congratulation: the fully assembled card drops in under a short headline with
/// a sparkle burst, so the reward is *seeing the thing they just built*.
///
/// The card is rendered through the same `MiniChartFactory`/`MetricViewFactory`
/// the dashboard uses — seeded by the caller with sample data so the chart looks
/// alive in the reveal — which is what lets one screen serve the goal, duration,
/// and every other tracker type from a single `Metric`.
struct TrackerDoneView: View {
    /// The fully assembled tracker, ready to render as a real card. Seeded with
    /// sample data by the caller so the chart looks alive in the reveal.
    let metric: Metric
    let color: Color
    /// An optional one-line recap under the card, e.g. "Goal: 8 glasses per day"
    /// or "Tracks up to 2h". Each path supplies its own; omitted when there's
    /// nothing meaningful to add.
    var recap: LocalizedStringKey?
    var onDone: () -> Void

    /// Drives the entrance: the card springs up from small and translucent once
    /// the view appears.
    @State private var hasAppeared = false
    /// A one-shot color bloom around the card that flashes as it lands, then
    /// settles to the resting glow.
    @State private var glow = false

    init(
        metric: Metric,
        color: Color = .accent,
        recap: LocalizedStringKey? = nil,
        onDone: @escaping () -> Void = {}
    ) {
        self.metric = metric
        self.color = color
        self.recap = recap
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

            if let recap {
                Text(recap)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

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
        .trackScreen("ManualTrackerCreationDone")
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

    /// The real card chrome, rendered from the assembled `Metric` through the
    /// same factories the dashboard uses — so whatever type the user built shows
    /// up here exactly as it will on the dashboard, just with sample data.
    private var card: some View {
        MetricView(
            mainColor: color,
            header: {
                MetricHeaderTextView(
                    title: metric.name,
                    emoji: metric.emoji,
                    value: MetricViewFactory.value(for: metric),
                    mainColor: color,
                    showAddButton: false
                )
            },
            chart: {
                AnyView(MiniChartFactory.make(from: metric))
                    .padding(.horizontal)
            }
        )
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

#Preview("Goal gauge") {
    let schema = MetricSchema.Fake.number(
        title: "Drink more water",
        emoji: "💧",
        unit: "glasses",
        min: 2,
        max: 8,
        granularity: 1,
        goal: 8,
        chart: .dailyGauge
    )
    NavigationStack {
        TrackerDoneView(
            metric: Metric(from: schema, color: .blue, data: Metric.fakeData(for: schema.config)),
            color: .blue,
            recap: "Goal: 8 glasses per day"
        )
    }
}

#Preview("Duration bars") {
    let schema = MetricSchema.Fake.duration(
        title: "Workout",
        emoji: "🏋️",
        granularity: "h",
        maxInSeconds: 2 * 3600,
        chart: .bar
    )
    NavigationStack {
        TrackerDoneView(
            metric: Metric(from: schema, color: .orange, data: Metric.fakeData(for: schema.config)),
            color: .orange,
            recap: "Tracks up to 2h"
        )
    }
}
