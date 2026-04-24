import SwiftUI

struct ContentView: View {
    @Environment(MetricStore.self) private var metricStore

    var body: some View {
        NavigationStack {
            if !metricStore.store.isEmpty || metricStore.isGenerating {
                Dashboard()
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
