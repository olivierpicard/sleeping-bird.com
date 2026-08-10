import PostHog
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \Metric.createdAt, order: .reverse) private var metrics:
        [Metric]
    @Environment(MetricGenerator.self) private var generator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    let onAddMetric: () -> Void
    @State private var editingMetric: Metric? = nil
    @State private var selectedMetric: Metric? = nil

    private let rowInsets = EdgeInsets(
        top: 8,
        leading: 16,
        bottom: 8,
        trailing: 16
    )

    var body: some View {
        List {
            ForEach(generator.pending) { _ in
                MetricPlaceholderView()
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            ForEach(metrics) { metric in
                MetricViewFactory.make(
                    from: metric,
                    in: colorScheme,
                    onAddTapped: { editingMetric = metric },
                    onCardTapped: { selectedMetric = metric }
                )
                .listRowInsets(rowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(metric)
                        PostHogSDK.shared.capture(
                            "metric_deleted",
                            properties: ["via": "swipe_actions"]
                        )
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        selectedMetric = metric
                    } label: {
                        Label("View details", systemImage: "chart.xyaxis.line")
                    }
                    Button {
                        editingMetric = metric
                    } label: {
                        Label("Add entry", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        delete(metric)
                        PostHogSDK.shared.capture(
                            "metric_deleted",
                            properties: ["via": "context_menu"]
                        )
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            FeedbackCardView()
                .listRowInsets(rowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .navigationDestination(item: $selectedMetric) { metric in
            MetricDetailView(metric: metric)
        }
        .sheet(item: $editingMetric) { metric in
            MetricEntrySheet(metric: metric) { point in
                try? metric.append(point)
                editingMetric = nil
                PostHogSDK.shared.capture(
                    "entry_added",
                    properties: [
                        "via": "dashboard",
                        "days_back": point.daysBack,
                    ]
                )
            }
            .trackScreen("AddEntry")
        }
        .scrollContentBackground(.hidden)
        .trackScreen("Dashboard")
        .navigationTitle("My Trackers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAddMetric) {
                    Label("Add a tracker", systemImage: "square.and.pencil")
                }
            }
        }
    }

    private func delete(_ metric: Metric) {
        modelContext.delete(metric)
    }
}

// MARK: - Previews

private func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
}

private func seedContainer(_ container: ModelContainer) -> ModelContainer {
    // Defined winner: Sugar (9), then Period (6), with the rest trailing.
    let breakoutEntries: [(Int, [String])] = [
        (13, ["Sugar", "Dairy"]),
        (12, ["Sugar"]),
        (11, ["Period", "Stress"]),
        (10, ["Sugar", "Period"]),
        (9, ["Stress"]),
        (8, ["Sugar", "Lack of sleep"]),
        (7, ["Period"]),
        (6, ["Sugar", "Dairy"]),
        (5, ["Sugar", "Period"]),
        (4, ["Sugar", "Stress"]),
        (3, ["Period", "Stress"]),
        (2, ["Sugar"]),
        (1, ["Period", "Lack of sleep"]),
        (0, ["Sugar", "Dairy"]),
    ]
    let breakoutData: [DataPoint] = breakoutEntries.map { offset, labels in
        DataPoint.category(daysAgo(offset), labels)
    }
    // Coherent gas fill-ups: ~twice a month (every ~16 days), going back ~4 months.
    let gasData: [DataPoint] = [4, 20, 35, 51, 66, 82, 97, 113].map { offset in
        DataPoint.datetime(daysAgo(offset))
    }
    // The cards below are shaped so the dashboard shows every badge state at
    // once. `MetricStatCalculator` compares the last seven whole days against
    // the seven before them, today excluded, and needs 14 days of history
    // before it will show a percent at all — so anything meant to carry one
    // reaches back ~20 days. Note `Metric.fakeData` defaults to `days: 14`,
    // which stops one day short of that gate.

    // ▲ +56% — a calm fortnight, then a heavier week. Prior block (days 14…8)
    // totals 16 cups against the last block's (days 7…1) 25.
    let coffeeData: [DataPoint] = [
        // Older context — only the chart sees these.
        (20, 2), (19, 3), (18, 2), (17, 2), (16, 3), (15, 2),
        // Prior block, days 14…8 — 16 cups.
        (14, 2), (13, 3), (12, 2), (11, 2), (10, 3), (9, 2), (8, 2),
        // Last block, days 7…1 — 25 cups.
        (7, 4), (6, 3), (5, 4), (4, 3), (3, 4), (2, 3), (1, 4),
        // Today, excluded from the comparison but drawn on the chart.
        (0, 2),
    ].map { offset, cups in
        DataPoint.number(daysAgo(offset), Double(cups))
    }

    // ▼ -15% — a well-rested week followed by a short one. Prior block totals
    // 53.5h against the last block's 45.5h.
    let sleepData: [DataPoint] = [
        (20, 7.5), (19, 7.0), (18, 8.0), (17, 7.5), (16, 7.0), (15, 7.5),
        // Prior block, days 14…8 — 53.5h.
        (14, 8.0), (13, 7.5), (12, 8.0), (11, 7.0), (10, 7.5), (9, 8.0), (8, 7.5),
        // Last block, days 7…1 — 45.5h.
        (7, 7.0), (6, 6.5), (5, 6.0), (4, 6.5), (3, 7.0), (2, 6.0), (1, 6.5),
        (0, 6.5),
    ].map { offset, hours in
        DataPoint.duration(daysAgo(offset), hours * 3600)
    }

    // ⚡ 6d streak — the last six days all clear the 10,000 goal, day 7 doesn't.
    let stepsData: [DataPoint] = [
        (20, 9_200), (19, 11_400), (18, 8_800), (17, 10_100), (16, 7_300),
        (15, 12_600), (14, 9_700), (13, 8_200), (12, 11_500), (11, 6_900),
        (10, 10_800), (9, 7_600), (8, 12_000), (7, 9_100),
        (6, 8_400),
        (5, 11_900), (4, 10_200), (3, 13_800), (2, 10_500), (1, 12_400),
        (0, 11_200),
    ].map { offset, steps in
        DataPoint.number(daysAgo(offset), Double(steps))
    }

    // ⚡ 5d streak — five straight "yes" days, broken by the miss on day 5.
    let medicationData: [DataPoint] = [
        (20, true), (19, true), (18, true), (17, true), (16, false),
        (15, true), (14, true), (13, true), (12, false), (11, true),
        (10, true), (9, true), (8, false), (7, true), (6, true),
        (5, false),
        (4, true), (3, true), (2, true), (1, true), (0, true),
    ].map { offset, taken in
        DataPoint.binary(daysAgo(offset), taken)
    }

    // 🌙 6d idle — three solid weeks of logging that simply stops. Idle
    // outranks everything, so the goal streak this would otherwise show is
    // suppressed: a chain isn't news when the tracker has gone quiet.
    let waterData: [DataPoint] = [
        (26, 2.4), (25, 2.6), (24, 2.0), (23, 2.8), (22, 2.5), (21, 2.2),
        (20, 2.6), (19, 2.9), (18, 2.1), (17, 2.5), (16, 2.7), (15, 2.3),
        (14, 2.6), (13, 2.4), (12, 2.8), (11, 2.5), (10, 2.2), (9, 2.7),
        (8, 2.5), (7, 2.6), (6, 2.4),
    ].map { offset, litres in
        DataPoint.number(daysAgo(offset), litres)
    }

    let schemas: [(MetricSchema, [DataPoint])] = [
        // number + gauge → LinearGaugeMiniChart · ⚡ 6d streak
        (
            MetricSchema.Fake.number(
                title: "Daily Steps",
                emoji: "👟",
                unit: "steps",
                min: 0,
                max: 50_000,
                granularity: 100,
                goal: 10_000,
                chart: .dailyGauge
            ),
            stepsData
        ),
        // number + line → LineMiniChart · no badge: a snapshot metric has no
        // percent branch, and bpm is a reading rather than something to total.
        (
            MetricSchema.Fake.number(
                title: "Heart Rate",
                emoji: "❤️",
                unit: "bpm",
                min: 40,
                max: 200,
                granularity: 1,
                goal: nil,
                behavior: .snapshot,
                chart: .line
            ),
            Metric.fakeData(
                for: MetricSchema.Fake.number(chart: .line).config,
                days: 21
            )
        ),

        // number + bar → BarMiniChart · 🌙 6d idle
        (
            MetricSchema.Fake.number(
                title: "Water Intake",
                emoji: "💧",
                unit: "L",
                min: 0,
                max: 5,
                granularity: 0.1,
                goal: 2.5,
                chart: .bar
            ),
            waterData
        ),

        // duration + bar → BarMiniChart · ▼ -15%
        (
            MetricSchema.Fake.duration(title: "Sleep", emoji: "🌙", chart: .bar),
            sleepData
        ),
        // categorySingleChoice → DividerBarMiniChart · never badges, and left
        // deliberately short (13 days) along with the breakout card below, so
        // the dashboard isn't uniformly badged.
        (
            MetricSchema.Fake.categorySingle(title: "Mood", emoji: "😊"),
            Metric.fakeData(for: MetricSchema.Fake.categorySingle().config)
        ),
        
        
        
        
        
        // datetime → EventCalendarMiniChart
        (
            MetricSchema.Fake.datetime(
                title: "When I put gas",
                emoji: "⛽️"
            ),
            gasData
        ),

        // categoryMultipleChoice → DividerBarMiniChart
        (
            MetricSchema.Fake.categoryMultiple(
                title: "Skin / Breakout triggers",
                emoji: "🧴",
                labels: ["Dairy", "Sugar", "Stress", "Period", "Lack of sleep"]
            ),
            breakoutData
        ),
        
        // binary → TrailingCalendarMiniChart · ⚡ 5d streak
        (
            MetricSchema.Fake.binary(title: "Medication Taken", emoji: "💊"),
            medicationData
        ),

        // number + bar → BarMiniChart · ▲ +56%
        (
            MetricSchema.Fake.number(
                title: "Coffees per day",
                emoji: "☕️",
                unit: "cups",
                min: 0,
                max: 8,
                granularity: 1,
                goal: nil,
                chart: .bar
            ),
            coffeeData
        ),
//        (
//            MetricSchema.Fake.binary(title: "Medication taken", emoji: "💊"),
//            []
//        ),
    ]
    for (schema, data) in schemas {
        container.mainContext.insert(Metric(from: schema, data: data))
    }
    return container
}

#Preview {
    let container = seedContainer(
        try! ModelContainer(
            for: Metric.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
    )
    NavigationStack {
        DashboardView(onAddMetric: {})
            .environment(MetricGenerator())
    }
    .modelContainer(container)
}

#Preview("Loading state", ) {
    let generator = MetricGenerator(pending: [
        .init(instruction: "track my coffee")
    ])
    let container = seedContainer(
        try! ModelContainer(
            for: Metric.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
    )
    NavigationStack {
        DashboardView(onAddMetric: {})

            .environment(generator)
    }
    .modelContainer(container)
}
