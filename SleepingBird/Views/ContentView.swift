import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var metrics: [Metric]
    @Environment(MetricGenerator.self) private var generator
    @State private var showModal = false
    private var isDashboardEmpty: Bool {
        metrics.isEmpty && generator.pending.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack {
                if isDashboardEmpty {
                    EmptyDashboardView(onAddMetric: { showModal = true })
                } else {
                    DashboardView(onAddMetric: { showModal = true })
                }
            }
            .background {
                isDashboardEmpty
                    ? EmptyDashboardBackground()
                    : EmptyDashboardBackground(intensity: 0.5)
            }
        }
        .sheet(
            isPresented: $showModal,
            onDismiss: { showModal = false }
        ) {
            MetricInputSheet()
                .presentationDetents([.large])
        }
    }
}

#Preview("Empty") {
    ContentView()
        .environment(MetricGenerator())
        .modelContainer(for: Metric.self, inMemory: true)
}

#Preview("With data") {
    let container = try! ModelContainer(
        for: Metric.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let schemas: [(MetricSchema, [DataPoint])] = [
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
        (
            MetricSchema.Fake.duration(title: "Sleep", emoji: "🌙", chart: .bar),
            Metric.fakeData(for: MetricSchema.Fake.duration().config)
        ),
        (
            MetricSchema.Fake.categorySingle(title: "Mood", emoji: "😊"),
            Metric.fakeData(for: MetricSchema.Fake.categorySingle().config)
        ),
        (
            MetricSchema.Fake.categoryMultiple(title: "Symptoms", emoji: "🤒"),
            Metric.fakeData(for: MetricSchema.Fake.categoryMultiple().config)
        ),
        (
            MetricSchema.Fake.binary(title: "Workout Done", emoji: "💪"),
            Metric.fakeData(for: MetricSchema.Fake.binary().config)
        ),
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
    return ContentView()
        .environment(MetricGenerator())
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}
