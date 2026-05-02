import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var metrics: [Metric]
    @Environment(MetricGenerator.self) private var generator

    var body: some View {
        NavigationStack {
            if metrics.isEmpty && generator.pending.isEmpty {
                EmptyDashboardView()
            } else {
                DashboardView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(MetricGenerator())
        .modelContainer(for: Metric.self, inMemory: true)
}
