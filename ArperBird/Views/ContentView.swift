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

    /// A single-format suggestion whose first AI load was run up front — while
    /// the empty dashboard still showed its "preparing" glow — so the flow opens
    /// past the loading spinner instead of stacking a second one behind that glow
    /// (see `EmptyDashboardView.prepareSeed` and `TrackerCreationModel.preloadSeed`).
    /// Keyed by the suggestion `id` so a stale prepare from an earlier tap is
    /// never applied to a different chip.
    private struct Prepared {
        let id: String
        let model: TrackerCreationModel
        let succeeded: Bool
    }
    @State private var prepared: Prepared?

    /// A creation-flow open. `.scratch` for the "+" button / empty-dashboard
    /// field CTA, `.seeded` for a tapped suggestion chip. `autofocus` rides on
    /// the scratch route so only the field CTA raises the keyboard on open — the
    /// "+" button opens the flow unfocused.
    private enum CreationRoute: Identifiable {
        case scratch(autofocus: Bool)
        // The warmed model rides *inside* the seeded route so it's captured
        // atomically with the presentation, alongside the seed. Reading it from
        // separate `@State` in the sheet builder let the first-ever sheet build
        // before that state propagated — dropping the warm model and flashing
        // the loading spinner (see `onAddMetric` / the sheet below).
        case seeded(TrackerSuggestion, warmed: Prepared?)

        var id: String {
            switch self {
            case .scratch: "scratch"
            case .seeded(let suggestion, _): suggestion.id
            }
        }

        var seed: TrackerSuggestion? {
            switch self {
            case .scratch: nil
            case .seeded(let suggestion, _): suggestion
            }
        }

        var warmed: Prepared? {
            switch self {
            case .scratch: nil
            case .seeded(_, let warmed): warmed
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
                    EmptyDashboardView(
                        onAddMetric: { suggestion in
                            // A chip arrives seeded — bundle its warmed model into
                            // the route *now*, while `prepared` is guaranteed set
                            // (this fires in the same continuation right after the
                            // preload `await`), so the model is captured atomically
                            // with presentation rather than read as separate state
                            // the first sheet build might miss. The field CTA (nil)
                            // commits to typing → focus the field, no keyboard for a
                            // chip. Match by `id` so a stale prepare from an earlier
                            // tap is never applied to a different chip.
                            if let suggestion {
                                let warmed = prepared.flatMap {
                                    $0.id == suggestion.id ? $0 : nil
                                }
                                route = .seeded(suggestion, warmed: warmed)
                            } else {
                                route = .scratch(autofocus: true)
                            }
                        },
                        // Runs a single-format chip's first AI load during its
                        // "preparing" glow so the flow can skip the loading
                        // spinner. The empty dashboard only calls this for
                        // single-format chips (multi-format ones open on the
                        // format picker, an interactive screen that absorbs the
                        // glow, so there's no second spinner to fold in).
                        prepareSeed: { suggestion in
                            let kind = suggestion.formats[0].kind
                            let model = TrackerCreationModel()
                            let ok = await model.preloadSeed(
                                kind: kind, name: suggestion.localizedName
                            )
                            prepared = .init(
                                id: suggestion.id, model: model, succeeded: ok
                            )
                        },
                        // Resolves the typed draft into a seed via the intent AI,
                        // so a field submit routes through the same seeded flow a
                        // chip does. Kept here beside `prepareSeed` so all the AI
                        // wiring lives at the ContentView level.
                        resolveIntent: { text in
                            let completion = try await IntentAiCompletion()
                                .generate(for: text)
                            return TrackerSuggestion(from: completion)
                        }
                    )
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
        .sheet(item: $route, onDismiss: { prepared = nil }) { route in
//            MetricInputSheet()
//                .presentationDetents([.large])
            // The warmed model rides inside `route` (bundled in `onAddMetric`), so
            // it's captured atomically with presentation. Reading `prepared` as
            // separate state here let the first-ever sheet build before that state
            // propagated, dropping the warm model and flashing the loading spinner.
            TrackerCreationFlow(
                seed: route.seed,
                autofocus: route.autofocus,
                preloaded: route.warmed?.model,
                preloadSucceeded: route.warmed?.succeeded ?? false
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
