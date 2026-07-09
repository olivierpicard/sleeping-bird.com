import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var metrics: [Metric]
    @Environment(MetricGenerator.self) private var generator
    /// The active creation-flow presentation. Driven via `sheet(item:)` so the
    /// seed is captured atomically with the presentation — setting a separate
    /// `isPresented` flag in the same tick would build the sheet before the
    /// seed state propagated, opening unseeded on the first tap.
    @State private var route: CreationRoute?

    /// A creation-flow open. `.scratch` for the "+" button / empty-dashboard
    /// field CTA, `.seeded` for a tapped suggestion chip. `autofocus` rides on
    /// the scratch route so only the field CTA raises the keyboard on open — the
    /// "+" button opens the flow unfocused.
    private enum CreationRoute: Identifiable {
        case scratch(autofocus: Bool)
        case seeded(TrackerSuggestion)

        var id: String {
            switch self {
            case .scratch: "scratch"
            case .seeded(let suggestion): suggestion.id
            }
        }

        var seed: TrackerSuggestion? {
            switch self {
            case .scratch: nil
            case .seeded(let suggestion): suggestion
            }
        }

        var autofocus: Bool {
            switch self {
            case .scratch(let autofocus): autofocus
            case .seeded: false
            }
        }
    }

    private var isDashboardEmpty: Bool {
        metrics.isEmpty && generator.pending.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack {
                if isDashboardEmpty {
                    EmptyDashboardView(onAddMetric: { suggestion in
                        // Field CTA (nil) commits to typing → focus the field;
                        // a chip arrives seeded, no keyboard.
                        route = suggestion.map(CreationRoute.seeded)
                            ?? .scratch(autofocus: true)
                    })
                } else {
                    DashboardView(onAddMetric: {
                        // The "+" button opens the flow unfocused.
                        route = .scratch(autofocus: false)
                    })
                }
            }
            .background {
                isDashboardEmpty
                    ? EmptyDashboardBackground()
                    : EmptyDashboardBackground(intensity: 0.5)
            }
        }
        .sheet(item: $route) { route in
//            MetricInputSheet()
//                .presentationDetents([.large])
            TrackerCreationFlow(
                seed: route.seed,
                autofocus: route.autofocus
            )
            .presentationDetents([.large])
        }
    }
}

#Preview("Empty") {
    ContentView()
        .environment(MetricGenerator())
        .environment(\.locale, Locale(identifier: "en_US"))
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
