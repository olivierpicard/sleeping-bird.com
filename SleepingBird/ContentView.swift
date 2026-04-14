import SwiftUI

struct ContentView: View {
    @State private var showModal = false

    var body: some View {
        Spacer()
        VStack(spacing: 28) {
            Text("It's empty here...\nFor now")
                .font(.largeTitle).fontWeight(.bold).multilineTextAlignment(
                    .center
                )

            Text("Create a new metric and start tracking your data")
                .multilineTextAlignment(.center)
        }.padding()
        Spacer()
        Button(action: {
            showModal = true
        }) {
            Text("Add a metric")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, maxHeight: 8)
                .padding()
        }

        .buttonStyle(.borderedProminent)
        .padding()
        .sheet(isPresented: $showModal, onDismiss: { showModal = false }) {
            VStack {
                MetricInputSheet()
            }.presentationDetents([.medium])
        }
    }
}

#Preview {
    ContentView()
}
