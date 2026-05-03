import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \Metric.createdAt, order: .reverse) private var metrics:
        [Metric]
    @Environment(MetricGenerator.self) private var generator
    @State private var editingMetric: Metric? = nil

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                ForEach(generator.pending) { _ in
                    MetricPlaceholderView()
                }
                ForEach(metrics) { metric in
                    MetricViewFactory.make(
                        from: metric,
                        onAddTapped: { editingMetric = metric }
                    )
                }
            }
            .padding()
        }
        .sheet(item: $editingMetric) { metric in
            MetricInputFactory.make(from: metric) { point in
                try? metric.append(point)
                editingMetric = nil
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Dashboard")
    }
}

// MARK: - Previews

private func seedContainer(_ container: ModelContainer) -> ModelContainer {
    let schemas: [(MetricSchema, [DataPoint])] = [
        (
            MetricSchema.Fake.number(title: "Daily Steps", emoji: "👟"),
            Metric.fakeData(for: MetricSchema.Fake.number().config)
        ),
        (
            MetricSchema.Fake.duration(title: "Sleep", emoji: "🌙"),
            Metric.fakeData(for: MetricSchema.Fake.duration().config)
        ),
        (
            MetricSchema.Fake.number(
                title: "Heart Rate",
                emoji: "❤️",
                unit: "bpm"
            ), Metric.fakeData(for: MetricSchema.Fake.number().config)
        ),
        (
            MetricSchema.Fake.binary(title: "Workout Done", emoji: "💪"),
            Metric.fakeData(for: MetricSchema.Fake.binary().config)
        ),
        (
            MetricSchema.Fake.categorySingle(title: "Mood", emoji: "😊"),
            Metric.fakeData(for: MetricSchema.Fake.categorySingle().config)
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
