//
//  TrackerDoneViewV2.swift
//  ArperBird
//
//  Created by Olivier Picard on 06/07/2026.
//
//  PROTOTYPE / MOCKUP — a restructured take on `TrackerDoneView`, built to
//  compare side by side. Not wired into the flow. Same public API as the
//  original (`metric`, `color`, `onDone`, a generic `recap` slot) so it drops in
//  as a replacement and the per-path recap views (`DoneGoalRecap`, …) render
//  unchanged.
//
//  The thesis: the original manufactures delight with effects (sparkle burst +
//  glow bloom + bounce + haptic, all at once) while floating in a centered void.
//  This version borrows `TrackerIntentView`'s premium bones instead — a real
//  nav-chrome spine, a top-down padding rhythm, ONE crisp delight moment, and
//  the editable chips promoted into a first-class panel with a home of its own.
//

import SwiftUI

/// The closing beat, restructured around composition rather than effects.
///
/// What changed vs. `TrackerDoneView`, and why:
/// - **A spine, not a void.** Real large-title nav chrome (like the intent
///   screen) anchors the screen top-down instead of centering everything
///   between `Spacer()`s. The title carries the congratulation, so the giant
///   floating 🎉 headline is gone.
/// - **One focal point.** The card is the hero. It arrives with a single crisp
///   spring + one quiet glow bloom + a success haptic — no sparkle confetti
///   competing for the eye. Restraint reads as premium; piled-on motion reads
///   as cheap.
/// - **A forward-looking voice.** The label above the card echoes the intent
///   screen's promise ("You, three weeks from now") so the reveal *pays off*
///   the thing the user was shown two screens ago, instead of a generic
///   "You're all set!".
/// - **Chips get a home.** The recap (line + editable chips) sits inside a
///   grouped "Fine-tune it" panel — the same material as the card — so the
///   tappable facets read as a real edit surface, not leftover garnish under a
///   spacer. That also teaches "these are interactive" by matching a settings
///   idiom the user already knows.
struct TrackerDoneViewV2<Recap: View>: View {
    /// The fully assembled tracker, ready to render as a real card. Seeded with
    /// sample data by the caller so the chart looks alive in the reveal.
    let metric: Metric
    let color: Color
    var onDone: () -> Void
    /// The recap content: the path's own recap line and its tappable chips.
    /// Rendered unchanged inside the "Fine-tune it" panel.
    @ViewBuilder var recap: () -> Recap

    /// Drives the entrance: the card springs up from small and translucent once
    /// the view appears.
    @State private var hasAppeared = false
    /// A one-shot color bloom around the card that flashes as it lands, then
    /// settles to the resting glow. The *only* effect — no sparkles.
    @State private var glow = false
    /// Locks the chart reveal once it has played. Charts capture their reveal at
    /// first appear, so this only matters for a chart that mounts *after* the
    /// reveal (a behavior toggle swapping bar↔line): once locked, the fresh chart
    /// is handed `animate: false` and renders static instead of replaying.
    @State private var revealLocked = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether a freshly-built chart should perform its entrance. True only
    /// during the initial reveal window and never under Reduce Motion.
    private var animateChart: Bool { !revealLocked && !reduceMotion }

    init(
        metric: Metric,
        color: Color = .accent,
        onDone: @escaping () -> Void = {},
        @ViewBuilder recap: @escaping () -> Recap
    ) {
        self.metric = metric
        self.color = color
        self.onDone = onDone
        self.recap = recap
    }

    var body: some View {
        VStack(spacing: 0) {

            // The zone label, anchored under the nav title — mirrors the intent
            // screen's response-zone label and pays off its promise.
            Text("")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 30)

            card
                .padding(.horizontal)
                .padding(.top, 10)
                // A single quiet bloom of the tracker's color as the card lands,
                // then it settles to the resting glow. No confetti.
                .shadow(
                    color: color.opacity(glow ? 0.7 : 0.25),
                    radius: glow ? 28 : 10
                )
                // Springs up from below and slightly overshoots so the card
                // *arrives* — the one delight beat, kept crisp.
                .scaleEffect(hasAppeared ? 1 : 0.7)
                .offset(y: hasAppeared ? 0 : 40)
                .opacity(hasAppeared ? 1 : 0)

            finePanel
                .padding(.horizontal)
                .padding(.top, 24)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 12)

            Spacer(minLength: 24)

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
        // A success cue the moment the card lands — the haptic stays; it's felt,
        // not seen, so it adds punch without visual clutter.
        .sensoryFeedback(.success, trigger: hasAppeared)
        .navigationTitle("Meet Your Tracker")
        .navigationSubtitle("Your tracker is ready to go")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden()
        .trackScreen("ManualTrackerCreationDoneV2")
        .onAppear {
            // A loose spring overshoots for a bouncy "pop" as the card settles.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                hasAppeared = true
            }
            // Bloom the glow just as the card reaches its mark, then ease it
            // back down to rest.
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeOut(duration: 0.25)) { glow = true }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeInOut(duration: 0.7)) { glow = false }
            }
            // Lock the reveal once the chart's entrance has finished, so any later
            // type-switch tweak mounts a static chart instead of replaying the
            // animation. Must stay after the *slowest* sweep — the calendar reveal
            // (`startDelay + calendarDuration`, ~1.9s) — or a swap cuts the wave off.
            Task {
                try? await Task.sleep(for: .seconds(1.9))
                revealLocked = true
            }
        }
    }

    // MARK: - Card

    /// The real card chrome, rendered from the assembled `Metric` through the
    /// same factories the dashboard uses — identical to the original.
    private var card: some View {
        MetricView(
            mainColor: color,
            header: {
                MetricHeaderTextView(
                    title: metric.name,
                    emoji: metric.emoji,
                    mainColor: color
                )
            },
            // Full tint, not the gray override the original used — this is the
            // reward, so the card should be the most alive it ever looks, exactly
            // like the intent screen's live preview. `animate` makes the data
            // perform on entry (bars/line rise, calendar cells scale in).
            chart: MiniChartFactory.make(from: metric, animate: animateChart)
        )
    }

    // MARK: - Fine-tune panel

    /// The editable facets, given a home: a grouped panel in the card's material
    /// with a quiet header, so the chips read as a real edit surface rather than
    /// floating text. The injected `recap` (line + chips) drops in unchanged.
    private var finePanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(color)
                Text("Fine-tune it")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Tap to edit")
                    .foregroundStyle(.tertiary)
            }
            .font(.footnote.weight(.medium))

            recap()
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Previews (reuse the real per-path recaps, exactly like the original)

#Preview("Goal gauge") {
    @Previewable @State var goal = 8.0
    @Previewable @State var granularity = 1.0
    @Previewable @State var unit = "glasses"
    let schema = MetricSchema.Fake.number(
        title: "Drink more water",
        emoji: "💧",
        unit: unit,
        min: goal * 0.2,
        max: goal,
        granularity: granularity,
        goal: goal,
        chart: .dailyGauge
    )
    NavigationStack {
        TrackerDoneViewV2(
            metric: Metric(
                from: schema,
                color: .blue,
                data: Metric.fakeData(for: schema.config)
            ),
            color: .blue
        ) {
            DoneGoalRecap(
                goalValue: goal,
                granularity: granularity,
                unit: unit,
                units: ["glasses", "ml", "liters"],
                color: .blue,
                onSelectUnit: { unit = $0 },
                onEditGoal: { goal = $0 },
                onEditGranularity: { granularity = $0 }
            )
        }
    }
}

#Preview("Number bar") {
    @Previewable @State var max = 12000.0
    @Previewable @State var granularity = 100.0
    @Previewable @State var behavior: MetricBehavior = .cumulative
    @Previewable @State var unit = "steps"
    let schema = MetricSchema.Fake.number(
        title: "Daily steps",
        emoji: "👟",
        unit: unit,
        min: 0,
        max: max,
        granularity: granularity,
        goal: nil,
        behavior: behavior,
        chart: behavior == .cumulative ? .bar : .line,
        method: behavior == .cumulative ? .numerical(.sum) : .numerical(.latest)
    )
    NavigationStack {
        TrackerDoneViewV2(
            metric: Metric(
                from: schema,
                color: .green,
                data: Metric.fakeData(for: schema.config)
            ),
            color: .green
        ) {
            DoneNumberRecap(
                maxValue: max,
                granularity: granularity,
                behavior: behavior,
                unit: unit,
                units: [
                    .init(
                        name: "steps",
                        defaultMax: 12000,
                        defaultGranularity: 100
                    ),
                    .init(name: "km", defaultMax: 10, defaultGranularity: 0.1),
                    .init(
                        name: "miles",
                        defaultMax: 6,
                        defaultGranularity: 0.1
                    ),
                ],
                color: .green,
                onEditMax: { max = $0 },
                onEditGranularity: { granularity = $0 },
                onToggleBehavior: {
                    behavior = behavior == .cumulative ? .snapshot : .cumulative
                },
                onSelectUnit: { unit = $0 }
            )
        }
    }
}

#Preview("Number line") {
    @Previewable @State var max = 12000.0
    @Previewable @State var granularity = 100.0
    @Previewable @State var behavior: MetricBehavior = .snapshot
    @Previewable @State var unit = "steps"
    let schema = MetricSchema.Fake.number(
        title: "Daily steps",
        emoji: "👟",
        unit: unit,
        min: 0,
        max: max,
        granularity: granularity,
        goal: nil,
        behavior: behavior,
        chart: behavior == .cumulative ? .bar : .line,
        method: behavior == .cumulative ? .numerical(.sum) : .numerical(.latest)
    )
    NavigationStack {
        TrackerDoneViewV2(
            metric: Metric(
                from: schema,
                color: .green,
                data: Metric.fakeData(for: schema.config)
            ),
            color: .green
        ) {
            DoneNumberRecap(
                maxValue: max,
                granularity: granularity,
                behavior: behavior,
                unit: unit,
                units: [
                    .init(
                        name: "temperature",
                        defaultMax: 300,
                        defaultGranularity: 1
                    )
                ],
                color: .green,
                onEditMax: { max = $0 },
                onEditGranularity: { granularity = $0 },
                onToggleBehavior: {
                    behavior = behavior == .cumulative ? .snapshot : .cumulative
                },
                onSelectUnit: { unit = $0 }
            )
        }
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
        TrackerDoneViewV2(
            metric: Metric(
                from: schema,
                color: .orange,
                data: Metric.fakeData(for: schema.config)
            ),
            color: .orange
        ) {
            DoneDurationRecap(
                maxSeconds: 2 * 3600,
                color: .orange,
                onUpdate: { _ in }
            )
        }
    }
}

#Preview("Date") {
    let schema = MetricSchema.Fake.datetime(
        title: "Anniversary",
        emoji: "📅",
        chart: .calendar
    )
    NavigationStack {}
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                TrackerDoneViewV2(
                    metric: Metric(
                        from: schema,
                        color: .indigo,
                        data: [
                            .datetime(.now),
                            .datetime(.now),
                            .datetime(.now),
                            .datetime(.now), 
                        ]
                    ),
                    color: .indigo
                ) {
                    DoneDateRecap()
                }
            }
        }
}

#Preview("Binary") {
    let schema = MetricSchema.Fake.binary(
        title: "Quit smoking",
        emoji: "🚭",
        chart: .calendar
    )
    NavigationStack {
        TrackerDoneViewV2(
            metric: Metric(
                from: schema,
                color: .teal,
                data: [.binary(.now, true)]
            ),
            color: .teal
        ) {
            DoneBinaryRecap()
        }
    }
}

#Preview("Category") {
    @Previewable @State var multiple = false
    let labels = ["Happy", "Calm", "Tired", "Anxious"]
    let schema = MetricSchema.Fake.categorySingle(
        title: "Mood",
        emoji: "🎭",
        labels: labels,
        chart: .pie
    )
    NavigationStack {
        TrackerDoneViewV2(
            metric: Metric(
                from: schema,
                color: .pink,
                data: Metric.fakeData(for: schema.config)
            ),
            color: .pink
        ) {
            DoneCategoryRecap(
                allowsMultiple: multiple,
                count: labels.count,
                color: .pink,
                onToggleChoice: { multiple.toggle() }
            )
        }
    }
}
