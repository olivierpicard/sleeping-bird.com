import SwiftData
import SwiftUI

struct MetricInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(MetricGenerator.self) private var generator
    @State private var instruction: String = ""
    @State private var isRecording: Bool = false
    private let transcriber: Transcriber
    private let buttonSize: CGFloat = 65

    init(
        instruction: String = "",
        transcriber: Transcriber = DeepgramFluxTranscriber()
    ) {
        _instruction = State(initialValue: instruction)
        self.transcriber = transcriber
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("What metric do you want to track?")
                    .font(.title).fontWeight(.semibold).multilineTextAlignment(
                        .center
                    )
                TextEditor(text: $instruction)
                Spacer()
                Button(action: { toggleRecording() }) {
                    Label(
                        isRecording ? "Stop" : "Dictate",
                        systemImage: isRecording
                            ? "stop" : "microphone"
                    )
                    .font(.system(size: buttonSize))
                }
                .symbolVariant(.circle.fill)
                .labelStyle(.iconOnly)
                .tint(isRecording ? .red : .accentColor)

            }
            .padding()
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        generator.generate(instruction: instruction, into: context)
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            transcriber.stop()
            isRecording = false
        } else {
            transcriber.start { text in
                instruction = text
            }
            isRecording = true
        }
    }
}

#Preview {
    MetricInputSheet(
        instruction: "I want to track how much coffee I drink per day"
    )
    .environment(MetricGenerator())
    .modelContainer(for: Metric.self, inMemory: true)
}
