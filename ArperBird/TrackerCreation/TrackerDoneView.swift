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
    /// On the choices path, the entry's selection mode. When set, a tappable chip
    /// surfaces it beside the recap so the user can flip single ↔ multiple from the
    /// reveal. Omitted (nil) on every other path, where it's meaningless.
    var categoryChoice: CategoryChoice?
    /// Invoked when the choice chip is tapped — the flow flips
    /// `categoryAllowsMultiple` on the model, which re-derives the recap and the
    /// card's chart (pie ↔ bar) in place.
    var onToggleChoice: () -> Void
    /// On the number path, the tracker's editable facets — its max, its
    /// cumulative/snapshot behavior, and its unit — surfaced as a row of tappable
    /// chips beneath the recap. Omitted (nil) on every other path, where they're
    /// meaningless.
    var numberFacets: NumberFacets?
    /// Invoked when the user commits a new maximum from the Max chip's editor
    /// sheet — the flow writes it back onto the model, which re-derives the card
    /// and the chip's displayed value in place.
    var onEditMax: (Double) -> Void
    /// Invoked when the behavior chip is tapped — the flow flips the model's
    /// cumulative ↔ snapshot behavior, which re-derives the recap and the card's
    /// chart (sum ↔ latest aggregation) in place.
    var onToggleBehavior: () -> Void
    /// Invoked when the user picks a unit from the Unit chip's inline menu — the
    /// flow re-anchors the model's unit (and its suggested max/granularity), which
    /// re-derives the card and the chip's displayed value in place. Only the AI's
    /// proposed units are offered, so every pick carries a known max.
    var onSelectUnit: (String) -> Void
    var onDone: () -> Void

    /// Drives the entrance: the card springs up from small and translucent once
    /// the view appears.
    @State private var hasAppeared = false
    /// A one-shot color bloom around the card that flashes as it lands, then
    /// settles to the resting glow.
    @State private var glow = false
    /// Whether the Max chip's editor sheet is up. Number path only.
    @State private var editingMax = false

    init(
        metric: Metric,
        color: Color = .accent,
        recap: LocalizedStringKey? = nil,
        categoryChoice: CategoryChoice? = nil,
        onToggleChoice: @escaping () -> Void = {},
        numberFacets: NumberFacets? = nil,
        onEditMax: @escaping (Double) -> Void = { _ in },
        onToggleBehavior: @escaping () -> Void = {},
        onSelectUnit: @escaping (String) -> Void = { _ in },
        onDone: @escaping () -> Void = {}
    ) {
        self.metric = metric
        self.color = color
        self.recap = recap
        self.categoryChoice = categoryChoice
        self.onToggleChoice = onToggleChoice
        self.numberFacets = numberFacets
        self.onEditMax = onEditMax
        self.onToggleBehavior = onToggleBehavior
        self.onSelectUnit = onSelectUnit
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

            recapSection

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
        // The Max chip raises this compact editor; committing writes the new bound
        // back through `onEditMax`, and the editor dismisses itself.
        .sheet(isPresented: $editingMax) {
            if let numberFacets {
                NumberMaxEditor(
                    value: numberFacets.maxValue,
                    unit: numberFacets.unit,
                    color: color,
                    onSave: onEditMax
                )
            }
        }
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

    // MARK: - Recap & choice link

    /// The recap line plus the path's tappable chips stacked beneath it: the
    /// single/multiple link on the choices path, or the max/behavior/unit row on
    /// the number path.
    @ViewBuilder
    private var recapSection: some View {
        VStack(spacing: 12) {
            if let recap {
                Text(recap)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if let categoryChoice {
                choiceChip(categoryChoice)
            }
            if let numberFacets {
                numberFacetsRow(numberFacets)
            }
        }
        .multilineTextAlignment(.center)
    }

    /// A quiet, tappable capsule carrying the choice glyph, its label, and a
    /// swap arrow — understated (secondary tint, soft fill, small type) so it sits
    /// below the recap without competing with the celebration, while still reading
    /// as a control that flips the selection mode in place.
    private func choiceChip(_ choice: CategoryChoice) -> some View {
        Button(action: onToggleChoice) {
            chipChrome {
                Image(systemName: choice.glyph)
                    .foregroundStyle(color)
                Text(choice.title)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Switches between single and multiple choice")
    }

    // MARK: - Number facet chips

    /// The number path's row of editable facets, surfaced as tappable chips: the
    /// tracker's max, its cumulative/snapshot behavior, and — when it has one —
    /// its unit. Interaction is wired up separately; here they just render.
    private func numberFacetsRow(_ facets: NumberFacets) -> some View {
        // A wrapping, centered row so each chip keeps its natural width: when the
        // three don't fit on one line they drop onto a second centered line rather
        // than squeezing a chip's text to wrap mid-word.
        WrappingHStack(alignment: .center, hSpacing: 8, vSpacing: 8) {
            if facets.unit != nil {
                unitChip(facets)
            }

            facetChip(
                glyph: "arrow.up.to.line.compact",
                label: "Max",
                value: facets.maxValue.formatted(.number),
                hint: "Edit the tracker's maximum value"
            ) { editingMax = true }

            facetChip(
                glyph: facets.behavior.glyph,
                label: facets.behavior.title,
                value: nil,
                hint: "Switch between cumulative and snapshot",
                trailing: "arrow.left.arrow.right"
            ) { onToggleBehavior() }
        }
        .padding(.horizontal)
    }

    /// The unit chip, surfaced as a `Menu` rather than a plain button: tapping it
    /// drops an inline list of the AI's proposed units, and picking one re-anchors
    /// the tracker's unit in place. There's deliberately no "type your own" entry —
    /// the reveal only offers what the AI modelled, so every choice carries a known
    /// max and granularity. The current unit is checkmarked. Shares the capsule
    /// chrome with the other facet chips so the row reads as one family.
    private func unitChip(_ facets: NumberFacets) -> some View {
        Menu {
            ForEach(facets.units, id: \.self) { option in
                Button(action: { onSelectUnit(option) }) {
                    if option == facets.unit {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            chipChrome {
                Image(systemName: "ruler")
                    .foregroundStyle(color)
                Text("Unit")
                if let unit = facets.unit {
                    Text(unit)
                        .foregroundStyle(.primary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        // Strip the Menu's default (automatic) button styling so its label renders
        // at the same size and tint as the plain-button facet chips beside it.
        .buttonStyle(.plain)
        .accessibilityLabel("Unit")
        .accessibilityHint("Choose the tracker's unit")
    }

    /// A single number facet chip: the facet glyph, its label, an optional
    /// emphasized value (e.g. the max), and an optional trailing glyph (e.g. the
    /// swap arrow on the behavior chip). Shares its capsule chrome with the choice
    /// chip so the reveal's chips read as one family.
    private func facetChip(
        glyph: String,
        label: LocalizedStringKey,
        value: String?,
        hint: String,
        trailing: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            chipChrome {
                Image(systemName: glyph)
                    .foregroundStyle(color)
                Text(label)
                if let value {
                    Text(value)
                        .foregroundStyle(.primary)
                }
                if let trailing {
                    Image(systemName: trailing)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }

    /// The shared capsule chrome behind every reveal chip — soft fill, a hairline
    /// tint stroke, secondary small type — so the choice and number-facet chips
    /// stay visually identical.
    private func chipChrome<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        HStack(spacing: 6, content: content)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.quaternary.opacity(0.5)))
            .overlay { Capsule().stroke(color.opacity(0.4), lineWidth: 1) }
    }
}

// MARK: - Choice link types

extension TrackerDoneView {
    /// A category entry's selection mode, surfaced by the reveal's choice chip.
    /// Tapping the chip flips between the two cases in place.
    enum CategoryChoice {
        case single
        case multiple

        var title: LocalizedStringKey {
            switch self {
            case .single: "Single choice"
            case .multiple: "Multiple choice"
            }
        }

        var glyph: String {
            switch self {
            case .single: "largecircle.fill.circle"
            case .multiple: "checkmark.square.fill"
            }
        }
    }

    /// The number path's editable facets, surfaced by the reveal's chip row:
    /// the tracker's max, its cumulative/snapshot behavior, and its unit. Nil on
    /// every other path, which hides the row.
    struct NumberFacets {
        /// The upper bound — shown on the Max chip and used to seed its editor.
        var maxValue: Double
        /// Whether readings accumulate (cumulative) or stand alone (snapshot).
        var behavior: MetricBehavior
        /// The unit label, or nil for a unitless tracker — which hides the unit
        /// chip.
        var unit: String?
        /// The AI's proposed units, offered in the unit chip's inline menu. The
        /// only choices the reveal exposes — there's no custom entry.
        var units: [String] = []
    }
}

// MARK: - Behavior chip presentation

extension MetricBehavior {
    /// The label shown on the reveal's behavior chip.
    var title: LocalizedStringKey {
        switch self {
        case .cumulative: "Cumulative"
        case .snapshot: "Snapshot"
        }
    }

    /// The glyph shown on the reveal's behavior chip: a summation sign for
    /// values that accumulate, a camera for independent snapshot readings.
    var glyph: String {
        switch self {
        case .cumulative: "sum"
        case .snapshot: "camera"
        }
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

#if DEBUG
/// A category reveal card whose chart matches the selection mode — pie for single,
/// bar for multiple — so toggling the choice link in the previews below re-reveals
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
    @Previewable @State var behavior: MetricBehavior = .cumulative
    @Previewable @State var unit = "steps"
    let schema = MetricSchema.Fake.number(
        title: "Daily steps",
        emoji: "👟",
        unit: unit,
        min: 0,
        max: max,
        granularity: 100,
        goal: nil,
        behavior: behavior,
        chart: .line,
        method: behavior == .cumulative ? .numerical(.sum) : .numerical(.latest)
    )
    NavigationStack {
        TrackerDoneView(
            metric: Metric(from: schema, color: .green, data: Metric.fakeData(for: schema.config)),
            color: .green,
            recap: "Counts up to \(max.formatted(.number)) \(unit)",
            numberFacets: .init(
                maxValue: max,
                behavior: behavior,
                unit: unit,
                units: ["steps", "km", "miles"]
            ),
            onEditMax: { max = $0 },
            onToggleBehavior: {
                behavior = behavior == .cumulative ? .snapshot : .cumulative
            },
            onSelectUnit: { unit = $0 }
        )
    }
}

#Preview("Choice link") {
    @Previewable @State var multiple = false
    NavigationStack {
        TrackerDoneView(
            metric: categoryRevealMetric(multiple: multiple),
            color: .pink,
            recap: multiple
                ? "Pick several from 4 categories"
                : "Pick one of 4 categories",
            categoryChoice: multiple ? .multiple : .single,
            onToggleChoice: { multiple.toggle() }
        )
    }
}
