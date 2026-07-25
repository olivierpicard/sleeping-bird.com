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
    // Coffees per day: realistic 1–4 cups, hovering around 2–3.
    let coffeeData: [DataPoint] = [
        (18, 3),(17, 2),(16, 4),(15, 1),(14, 1), (13, 3), (12, 3), (11, 2), (10, 4), (9, 1), (8, 3), (7, 2),
        (6, 3), (5, 2), (4, 4), (3, 1), (2, 3), (1, 2), (0, 4),
    ].map { offset, cups in
        DataPoint.number(daysAgo(offset), Double(cups))
    }

    let schemas: [(MetricSchema, [DataPoint])] = [
        // number + gauge → LinearGaugeMiniChart
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
            Metric.fakeData(
                for: MetricSchema.Fake.number(chart: .dailyGauge).config
            )
        ),
        // number + line → LineMiniChart
        (
            MetricSchema.Fake.number(
                title: "Heart Rate",
                emoji: "❤️",
                unit: "bpm",
                min: 40,
                max: 200,
                granularity: 1,
                goal: nil,
                chart: .line
            ),
            Metric.fakeData(for: MetricSchema.Fake.number(chart: .line).config)
        ),
        
        // duration + bar → BarMiniChart
        (
            MetricSchema.Fake.duration(title: "Sleep", emoji: "🌙", chart: .bar),
            Metric.fakeData(for: MetricSchema.Fake.duration().config)
        ),
        // categorySingleChoice → DividerBarMiniChart
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
        
        // binary → TrailingCalendarMiniChart
        (
            MetricSchema.Fake.binary(title: "Medication Taken", emoji: "💊"),
            Metric.fakeData(for: MetricSchema.Fake.binary().config)
        ),

        // number + bar → BarMiniChart
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
