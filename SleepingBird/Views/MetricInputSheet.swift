import SwiftData
import SwiftUI

private struct PlaceholderExample {
    let text: String
    let duration: TimeInterval
}

private let placeholderExamples: [PlaceholderExample] = [
    .init(text: "Track my daily goal of 2L water", duration: 2),
    .init(text: "How many cups of coffee do I drink?", duration: 3.0),
    .init(
        text: "I want to know how long my meditation sessions are",
        duration: 4.0
    ),
    .init(text: "Measure my belly pain", duration: 2.5),
    .init(text: "I want to note each time I put gas in my car", duration: 3.5),
    .init(text: "Track my mood using emoji", duration: 3.0),
    .init(text: "Make a counter for each time I go to pee", duration: 3.0),
]

struct MetricInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(MetricGenerator.self) private var generator
    @State private var instruction: String = ""
    @State private var fontSize: CGFloat = 40
    @State private var placeholderIndex: Int = 0
    private let transcriber: Transcriber
    private let spectrumLogic: SpectrumViewModel
    private let autoStartTranscription: Bool

    init(
        instruction: String = "",
        transcriber: Transcriber = DeepgramNova3Transcriber(),
        spectrumLogic: SpectrumViewModel = LiveSpectrumViewModel(),
        autoStartTranscription: Bool = false
    ) {
        _instruction = State(initialValue: instruction)
        let initialSize: CGFloat =
            40 - (40 - 16) * min(1, CGFloat(instruction.count) / 250)
        _fontSize = State(initialValue: initialSize)
        self.transcriber = transcriber
        self.spectrumLogic = spectrumLogic
        self.autoStartTranscription = autoStartTranscription
    }

    private func computeFontSize(for text: String) -> CGFloat {
        let maxSize: CGFloat = 37
        let minSize: CGFloat = 16
        let length = CGFloat(text.count)
        let progress = min(1, length / 250)
        return maxSize - (maxSize - minSize) * progress
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)
                Group {
                    if instruction.isEmpty {
                        Text(placeholderExamples[placeholderIndex].text)
                            .foregroundStyle(.tertiary)
                            .id(placeholderIndex)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom)
                                        .combined(with: .opacity)
                                        .animation(.easeIn(duration: 0.5)),
                                    removal: .move(edge: .top)
                                        .combined(with: .opacity)
                                        .animation(.easeOut(duration: 0.3))
                                )
                            )
                    } else {
                        Text(instruction)
                    }
                }
                .font(.system(size: fontSize, weight: .semibold))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: fontSize)
                .onChange(of: instruction) { _, newValue in
                    fontSize = computeFontSize(for: newValue)
                }
                .task(id: instruction.isEmpty) {
                    guard instruction.isEmpty else { return }
                    while !Task.isCancelled {
                        let nanos = UInt64(
                            placeholderExamples[placeholderIndex].duration
                                * 1_000_000_000
                        )
                        try? await Task.sleep(nanoseconds: nanos)
                        if Task.isCancelled { return }
                        withAnimation {
                            placeholderIndex =
                                (placeholderIndex + 1)
                                % placeholderExamples.count
                        }
                    }
                }
                Spacer(minLength: 0)
                SpectrumBarView(viewModel: spectrumLogic)
                    .padding(.bottom, 25)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background {
                ReactiveMeshBorder(magnitudes: spectrumLogic.magnitudes)
                    .ignoresSafeArea()
            }
            .presentationDragIndicator(.visible)
            .task {
                if autoStartTranscription {
                    transcriber.start { instruction = $0 }
                }
            }
            .onDisappear { transcriber.stop() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        generator.generate(
                            instruction: instruction,
                            into: context
                        )
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}

#Preview("Default instruction") {
    @Previewable @State var showSheet = true

    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        MetricInputSheet(
            instruction: "I want to track how much coffee I drink per day",
            transcriber: FakeTranscriber(),
            spectrumLogic: FakeSpectrumViewModel(),
        )
    }
    .presentationDetents([.large])
    .environment(MetricGenerator())
    .modelContainer(for: Metric.self, inMemory: true)
}

#Preview("No instruction") {
    @Previewable @State var showSheet = true

    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        MetricInputSheet(
            transcriber: FakeTranscriber(),
            spectrumLogic: FakeSpectrumViewModel(),
        )
    }
    .presentationDetents([.large])
    .environment(MetricGenerator())
    .modelContainer(for: Metric.self, inMemory: true)
}

#Preview("Fake transcribing") {
    @Previewable @State var showSheet = true

    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        MetricInputSheet(
            instruction: "",
            transcriber: FakeTranscriber(),
            spectrumLogic: FakeSpectrumViewModel(),
            autoStartTranscription: true
        )
    }
    .presentationDetents([.large])
    .environment(MetricGenerator())
    .modelContainer(for: Metric.self, inMemory: true)
}

#Preview("Real Deepgram") {
    @Previewable @State var showSheet = true

    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        MetricInputSheet(autoStartTranscription: true)
    }
    .presentationDetents([.large])
    .environment(MetricGenerator())
    .modelContainer(for: Metric.self, inMemory: true)
}
