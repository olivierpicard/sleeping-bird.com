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
/// This is the celebration *shell* only — headline, card, sparkles, and the
/// "Add to dashboard" button. The recap line and any per-path chips are injected
/// as the `recap` slot, so the shell stays agnostic to the tracker type while
/// each path supplies its own dumb recap view (e.g. `DoneNumberRecap`). The
/// parent (`DoneRevealStep`) picks the right one and wires its behaviour.
///
/// The card is rendered through the same `MiniChartFactory`/`MetricViewFactory`
/// the dashboard uses — seeded by the caller with sample data so the chart looks
/// alive in the reveal — which is what lets one screen serve the goal, duration,
/// and every other tracker type from a single `Metric`.
struct TrackerDoneView<Recap: View>: View {
    /// The fully assembled tracker, ready to render as a real card. Seeded with
    /// sample data by the caller so the chart looks alive in the reveal.
    /// `@Bindable` so the editable header can write the renamed title straight
    /// back into the model, re-rendering the card in place.
    @Bindable var metric: Metric
    /// Where the editable header writes the name/emoji. In the real flow these
    /// point at the `TrackerCreationModel` — the source of truth that
    /// `persistMetric` rebuilds the dashboard card from — so edits actually stick.
    /// When nil (previews) they fall back to the transient `metric`.
    var nameBinding: Binding<String>? = nil
    var emojiBinding: Binding<String>? = nil
    var onDone: () -> Void
    /// The recap content stacked beneath the card: the path's own recap line and
    /// any tappable chips. Each path supplies its own dumb view; the shell just
    /// drops it into place.
    @ViewBuilder var recap: () -> Recap

    @Environment(\.colorScheme) private var colorScheme

    /// The tracker's color, read straight off `metric` and passed through the
    /// readability filter — every colored element of the reveal (glow, sparkles,
    /// card, CTA) shares this one corrected shade, so the celebration always
    /// matches the card it's celebrating rather than a separately-threaded color
    /// that could drift out of sync with it.
    private var displayColor: Color {
        metric.displayColor(in: colorScheme)
    }

    /// Drives the entrance: the card springs up from small and translucent once
    /// the view appears.
    @State private var hasAppeared = false
    /// A one-shot color bloom around the card that flashes as it lands, then
    /// settles to the resting glow.
    @State private var glow = false

    init(
        metric: Metric,
        name: Binding<String>? = nil,
        emoji: Binding<String>? = nil,
        onDone: @escaping () -> Void = {},
        @ViewBuilder recap: @escaping () -> Recap
    ) {
        self.metric = metric
        self.nameBinding = name
        self.emojiBinding = emoji
        self.onDone = onDone
        self.recap = recap
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
                    color: displayColor.opacity(glow ? 0.9 : 0.35),
                    radius: glow ? 36 : 10
                )
                // Launch small from below and overshoot into place so the card
                // really *arrives* rather than fading in.
                .scaleEffect(hasAppeared ? 1 : 0.4)
                .offset(y: hasAppeared ? 0 : 70)
                .opacity(hasAppeared ? 1 : 0)

            recap()

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
            .padding()
        }
        // Tap anywhere off the fields to dismiss the keyboard — the emoji
        // keyboard has no return key, so this is the only way out.
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
        }
        // A scattered sparkle burst behind everything, sized to the celebration.
        .background(alignment: .top) { SparkleBurst(color: displayColor, active: hasAppeared) }
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
        // Back-arrow vs. close (X) is decided by the flow's `NavChrome`, which
        // knows whether this reveal is the user's entry point (empty-dashboard
        // single-format → X) or a pushed step (format-picker → back). It's
        // applied by the parent as a sibling `.toolbar`, not a descendant of
        // this body, so it doesn't inherit the ambient tint below.
        // Ambient tint: catches anything on this screen that isn't already
        // explicitly colored (text field cursor, menu chevrons, keyboard
        // accessory) so the whole reveal reads as the tracker's color, not
        // the app accent.
        .tint(displayColor)
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: 6) {
            Text("✅")
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
            mainColor: displayColor,
            header: {
                // No `focus` binding — the field is editable but never
                // auto-focuses, so the reveal isn't hijacked by the keyboard.
                // Edits flow to `nameBinding`/`emojiBinding` (the model in the
                // real flow) so they survive `persistMetric`; previews fall back
                // to the transient `metric`.
                MetricHeaderEditingView(
                    emoji: emojiBinding?.wrappedValue ?? metric.emoji,
                    mainColor: displayColor,
                    title: nameBinding ?? $metric.name,
                    placeholder: "Tracker name",
                    editableEmoji: emojiBinding ?? $metric.emoji
                )
            },
            chart: MiniChartFactory.make(from: metric, colorOverride: displayColor)
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
    // Drive the goal, step and unit from state so editing the Goal/Step chips and
    // picking a unit re-derive the gauge *and* the chips in place — mirroring
    // `DoneRevealStep` in the real flow.
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
        TrackerDoneView(
            metric: Metric(from: schema, color: .blue, data: Metric.fakeData(for: schema.config))
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
            // No custom unit in this preview — `customUnit` defaults to nil.
        }
    }
}

#Preview("Duration bars") {
    let schema = MetricSchema.Fake.duration(
        title: "Workout",
        emoji: "🏋️",
        chart: .bar
    )
    NavigationStack {
        TrackerDoneView(
            metric: Metric(from: schema, color: .orange, data: Metric.fakeData(for: schema.config))
        ) {
            DoneDurationRecap()
        }
    }
}

#if DEBUG
/// A category reveal card whose chart matches the selection mode — pie for single,
/// bar for multiple — so toggling the choice link in the preview below re-reveals
/// the right chart, mirroring `TrackerCreationFlow.doneSchema()`.
private func categoryRevealMetric(multiple: Bool) -> Metric {
    let labels = ["Happy", "Calm", "Tired", "Anxious"]
    let schema =
        multiple
        ? MetricSchema.Fake.categoryMultiple(
            title: "Mood", emoji: "🎭", labels: labels, chart: .bar)
        : MetricSchema.Fake.categorySingle(
            title: "Mood", emoji: "🎭", labels: labels, chart: .pie)
    return Metric(from: schema, color: .pink, data: Metric.fakeData(for: schema.config))
}
#endif

#Preview("Number facets") {
    // Drive the max and behavior from state so editing the Max chip and tapping
    // the behavior chip re-derive the card *and* the chips in place — mirroring
    // `DoneRevealStep` in the real flow.
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
        TrackerDoneView(
            metric: Metric(from: schema, color: .green, data: Metric.fakeData(for: schema.config))
        ) {
            DoneNumberRecap(
                maxValue: max,
                granularity: granularity,
                behavior: behavior,
                unit: unit,
                units: [
                    .init(name: "steps", defaultMax: 12000, defaultGranularity: 100),
                    .init(name: "km", defaultMax: 10, defaultGranularity: 0.1),
                    .init(name: "miles", defaultMax: 6, defaultGranularity: 0.1),
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

#Preview("Category") {
    @Previewable @State var multiple = false
    NavigationStack {
        TrackerDoneView(
            metric: categoryRevealMetric(multiple: multiple)
        ) {
            DoneCategoryRecap(
                allowsMultiple: multiple,
                count: 4,
                color: .pink,
                onToggleChoice: { multiple.toggle() }
            )
        }
    }
}

#Preview("Date") {
    // Seeded with `Metric.fakeData` like every other path — a spread of dates
    // the user never picked reads as an example, where a lone real "today" cell
    // read as data the tracker already held (decision 0010).
    let schema = MetricSchema.Fake.datetime(
        title: "Anniversary",
        emoji: "📅",
        chart: .calendar
    )
    NavigationStack {
        TrackerDoneView(
            metric: Metric(
                from: schema, color: .indigo, data: Metric.fakeData(for: schema.config))
        ) {
            DoneDateRecap()
        }
    }
}

#Preview("Binary") {
    // Seeded with `Metric.fakeData` like every other path — a week of mixed
    // yes/no days reads as an example, where a lone real "today" cell read as
    // data the tracker already held (decision 0010).
    let schema = MetricSchema.Fake.binary(
        title: "Quit smoking",
        emoji: "🚭",
        chart: .calendar
    )
    NavigationStack {
        TrackerDoneView(
            metric: Metric(
                from: schema, color: .teal, data: Metric.fakeData(for: schema.config))
        ) {
            DoneBinaryRecap()
        }
    }
}
