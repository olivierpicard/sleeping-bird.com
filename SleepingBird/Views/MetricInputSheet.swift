import SwiftData
import SwiftUI
import UIKit

private struct PlaceholderExample {
    let text: String
    let duration: TimeInterval
}

private let placeholderExamples: [PlaceholderExample] = [
    .init(text: String(localized: "metric_input_sheet.placeholder.water"), duration: 2),
    .init(text: String(localized: "metric_input_sheet.placeholder.coffee"), duration: 3.0),
    .init(text: String(localized: "metric_input_sheet.placeholder.meditation"), duration: 4.0),
    .init(text: String(localized: "metric_input_sheet.placeholder.pain"), duration: 2.5),
    .init(text: String(localized: "metric_input_sheet.placeholder.fuel"), duration: 3.5),
    .init(text: String(localized: "metric_input_sheet.placeholder.mood"), duration: 3.0),
    .init(text: String(localized: "metric_input_sheet.placeholder.pee"), duration: 3.0),
]

struct MetricInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(MetricGenerator.self) private var generator
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @State private var instruction: String = ""
    @State private var fontSize: CGFloat = 40
    @State private var placeholderIndex: Int = 0
    @State private var isListening: Bool = false
    @State private var isEditing: Bool = false
    @State private var showMicPermissionAlert: Bool = false
    @FocusState private var isFocused: Bool
    @Namespace private var glassNamespace
    private let transcriber: Transcriber
    private let spectrumLogic: SpectrumViewModel

    init(
        instruction: String = "",
        transcriber: Transcriber = DeepgramNova3Transcriber(),
        spectrumLogic: SpectrumViewModel = LiveSpectrumViewModel(),
        showMicPermissionAlert: Bool = false
    ) {
        _instruction = State(initialValue: instruction)
        _fontSize = State(
            initialValue: Self.computeFontSize(for: instruction)
        )
        _showMicPermissionAlert = State(initialValue: showMicPermissionAlert)
        self.transcriber = transcriber
        self.spectrumLogic = spectrumLogic
    }

    private func enterEditMode() {
        if isListening { toggleMic() }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isEditing = true
        }
        isFocused = true
    }

    private func exitEditMode() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isEditing = false
        }
        isFocused = false
    }

    private func toggleMic() {
        if !isListening && !transcriber.hasMicPermission {
            showMicPermissionAlert = true
            return
        }
        let willListen = !isListening
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isListening = willListen
        }
        if willListen {
            transcriber.start { instruction = $0 }
        } else {
            transcriber.stop()
        }
    }

    private static func computeFontSize(for text: String) -> CGFloat {
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
                    if isEditing {
                        TextField("", text: $instruction, axis: .vertical)
                            .focused($isFocused)
                            .multilineTextAlignment(.center)
                            .onChange(of: instruction) { _, new in
                                if new.contains("\n") {
                                    instruction = new.replacingOccurrences(
                                        of: "\n",
                                        with: ""
                                    )
                                    exitEditMode()
                                }
                            }
                    } else if instruction.isEmpty {
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
                            .onTapGesture { enterEditMode() }
                    } else {
                        Text(instruction)
                            .onTapGesture { enterEditMode() }
                    }
                }
                .font(.system(size: fontSize, weight: .semibold))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: fontSize)
                .onChange(of: instruction) { _, new in
                    fontSize = Self.computeFontSize(for: new)
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
                bottomBar
                    .padding(.bottom, isEditing ? 8 : 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background {
                if isListening {
                    ReactiveMeshBorder(magnitudes: spectrumLogic.magnitudes)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .presentationDragIndicator(.visible)
            .alert(
                "metric_input_sheet.mic_permission.title",
                isPresented: $showMicPermissionAlert
            ) {
                Button("metric_input_sheet.mic_permission.settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button("metric_input_sheet.mic_permission.cancel", role: .cancel) {}
            } message: {
                Text("metric_input_sheet.mic_permission.message")
            }
            .onDisappear { transcriber.stop() }
            .navigationTitle("Add a metric").navigationBarTitleDisplayMode(
                .inline
            )
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
                            into: context,
                            locale: locale
                        )
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.indigo)
                    .disabled(instruction.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        GlassEffectContainer(spacing: 40) {
            HStack(spacing: isListening ? 12 : 0) {
                if !isEditing && !isListening { Spacer(minLength: 0) }
                keyboardButton
                    .padding(.trailing, isEditing ? 0 : -5)
                if isEditing {
                    Spacer(minLength: 0)
                } else {
                    if isListening {
                        SpectrumBarView(viewModel: spectrumLogic)
                            .frame(maxWidth: .infinity)
                            .transition(
                                .opacity.combined(with: .scale(scale: 0.92))
                            )
                    }
                    micButton
                    if !isListening { Spacer(minLength: 0) } 
                }
            }
        }
    }

    private var micButton: some View {
        Button(action: toggleMic) {
            Image(systemName: "mic")
                .font(.largeTitle)
        }
        .buttonStyle(.glass)
        .controlSize(.extraLarge)
        .glassEffectID("mic", in: glassNamespace)
    }

    private var keyboardButton: some View {
        Button(action: { isEditing ? exitEditMode() : enterEditMode() }) {
            Image(
                systemName: isEditing
                    ? "keyboard.chevron.compact.down" : "keyboard"
            )
            .font(.title2)
        }
        .buttonStyle(.glass)
        .controlSize(.extraLarge)
        .glassEffectID("keyboard", in: glassNamespace)
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
        )
    }
    .presentationDetents([.large])
    .environment(MetricGenerator())
    .modelContainer(for: Metric.self, inMemory: true)
}

#Preview("Mic permission denied") {
    @Previewable @State var showSheet = true

    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        MetricInputSheet(
            transcriber: FakeTranscriber(hasMicPermission: false),
            spectrumLogic: FakeSpectrumViewModel(),
            showMicPermissionAlert: true,
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
        MetricInputSheet()
    }
    .presentationDetents([.large])
    .environment(MetricGenerator())
    .modelContainer(for: Metric.self, inMemory: true)
}
