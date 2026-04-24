import SwiftUI

struct MetricInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MetricStore.self) private var metricStore
    @State private var instruction: String = ""
    @State private var isRecording: Bool = false
    private let transcriber: Transcriber
    private let BUTTON_SIZE: CGFloat = 65

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
                    .font(.system(size: BUTTON_SIZE))
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
                        metricStore.create(instruction: instruction)
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
                //                instruction += (instruction.isEmpty ? "" : " ") + text
                instruction = text
            }
            isRecording = true
        }
    }
}

#Preview {
    //        MetricInputSheet()
    MetricInputSheet(
        instruction: "I want to track how much coffee I drink per day"
    ).environment(MetricStore())
    //        MetricInputSheet(
    //            instruction:
    //                "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum. Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum. "
    //        )
}
