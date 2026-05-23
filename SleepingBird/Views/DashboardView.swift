import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \Metric.createdAt, order: .reverse) private var metrics:
        [Metric]
    @Environment(MetricGenerator.self) private var generator
    @State private var editingMetric: Metric? = nil
    @State private var selectedMetric: Metric? = nil

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                ForEach(generator.pending) { _ in
                    MetricPlaceholderView()
                }
                ForEach(metrics) { metric in
                    MetricViewFactory.make(
                        from: metric,
                        onAddTapped: { editingMetric = metric },
                        onCardTapped: { selectedMetric = metric }
                    )
                }
            }
            .padding()
        }
        .navigationDestination(item: $selectedMetric) { metric in
            MetricDetailView(metric: metric)
        }
        .sheet(item: $editingMetric) { metric in
            MetricInputFactory.make(from: metric) { point in
                try? metric.append(point)
                editingMetric = nil
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Today")
    }
}

// MARK: - Previews

private func seedContainer(_ container: ModelContainer) -> ModelContainer {
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
        // categoryMultipleChoice → DividerBarMiniChart
        (
            MetricSchema.Fake.categoryMultiple(title: "Symptoms", emoji: "🤒"),
            Metric.fakeData(for: MetricSchema.Fake.categoryMultiple().config)
        ),
        // binary → TrailingCalendarMiniChart
        (
            MetricSchema.Fake.binary(title: "Workout Done", emoji: "💪"),
            Metric.fakeData(for: MetricSchema.Fake.binary().config)
        ),
        // datetime → EventCalendarMiniChart
        (
            MetricSchema.Fake.datetime(
                title: "Doctor Appointments",
                emoji: "🏥"
            ),
            Metric.fakeData(for: MetricSchema.Fake.datetime().config)
        ),
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
        DashboardView()
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
        DashboardView()

            .environment(generator)
    }
    .modelContainer(container)
}
