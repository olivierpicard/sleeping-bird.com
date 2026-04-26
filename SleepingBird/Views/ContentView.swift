import SwiftUI

struct ContentView: View {
    @Environment(MetricStore.self) private var metricStore

    var body: some View {
        NavigationStack {
            if !metricStore.metrics.isEmpty || metricStore.isGenerating {
                DashboardView()
            } else {
                EmptyDashboardView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(MetricStore())
}
