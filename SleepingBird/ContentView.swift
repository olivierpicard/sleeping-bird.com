import SwiftUI

struct ContentView: View {
    @State private var showModal = false
    @State private var useFluxTranscriber = true

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("It's empty here...\nFor now")
                .font(.largeTitle).fontWeight(.bold).multilineTextAlignment(
                    .center
                )

            Text("Create a new metric and start tracking your data")
                .multilineTextAlignment(.center)

            Spacer()
            
            
                

            Toggle("Use Flux Transcriber", isOn: $useFluxTranscriber).frame(
                maxWidth: 300
            ).padding()

            Button(action: {
                showModal = true
            }) {
                Text("Add a metric")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, maxHeight: 8)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $showModal, onDismiss: { showModal = false }) {
                VStack {
                    MetricInputSheet(
                        transcriber: useFluxTranscriber
                            ? DeepgramFluxTranscriber()
                            : DeepgramNova3Transcriber()
                    )
                }.presentationDetents([.medium])
            }
        }.padding()
    }
}

#Preview {
    ContentView()
}
