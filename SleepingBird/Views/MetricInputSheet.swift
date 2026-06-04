import PostHog
import SwiftData
import SwiftUI
import UIKit

private enum InputMode: String {
    case keyboard
    case label
}

private enum SubmitTrigger: String {
    case keyboard
    case toolbar
}

private struct PlaceholderExample {
    let text: String
    let duration: TimeInterval
}

private let placeholderExamples: [PlaceholderExample] = [
    .init(
        text: String(localized: "metric_input_sheet.placeholder.water"),
        duration: 2
    ),
    .init(
        text: String(localized: "metric_input_sheet.placeholder.coffee"),
        duration: 3.0
    ),
    .init(
        text: String(localized: "metric_input_sheet.placeholder.meditation"),
        duration: 4.0
    ),
    .init(
        text: String(localized: "metric_input_sheet.placeholder.pain"),
        duration: 2.5
    ),
    .init(
        text: String(localized: "metric_input_sheet.placeholder.fuel"),
        duration: 3.5
    ),
    .init(
        text: String(localized: "metric_input_sheet.placeholder.mood"),
        duration: 3.0
    ),
    .init(
        text: String(localized: "metric_input_sheet.placeholder.pee"),
        duration: 3.0
    ),
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
    @State private var showMicBlockedAlert: Bool = false
    @State private var usage: MicUsageTracker
    @State private var autoCutTask: Task<Void, Never>?
    @State private var listenStartedAt: Date?
    @FocusState private var isFocused: Bool
    @Namespace private var glassNamespace
    private let transcriber: Transcriber
    private let spectrumLogic: SpectrumViewModel

    /// Hard cap on a single listening session. Live dictation streams to a
    /// paid speech API, so an unattended mic is cut off after this long.
    private let maxListeningDuration: TimeInterval = 60

    init(
        instruction: String = "",
        transcriber: Transcriber = DeepgramNova3Transcriber(
            config: .make(language: VoiceLanguageOption.saved.id)
        ),
        spectrumLogic: SpectrumViewModel = LiveSpectrumViewModel(),
        showMicPermissionAlert: Bool = false,
        usage: MicUsageTracker = MicUsageTracker()
    ) {
        _instruction = State(initialValue: instruction)
        _fontSize = State(
            initialValue: Self.computeFontSize(for: instruction)
        )
        _showMicPermissionAlert = State(initialValue: showMicPermissionAlert)
        _usage = State(initialValue: usage)
        self.transcriber = transcriber
        self.spectrumLogic = spectrumLogic
    }

    private func enterEditMode(via mode: InputMode) {
        if isListening { toggleMic() }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isEditing = true
        }
        isFocused = true
        PostHogSDK.shared.capture(
            "instruction_edition_entered",
            properties: ["input_mode": mode.rawValue]
        )
    }

    private func exitEditMode() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isEditing = false
        }
        isFocused = false
    }

    private func submit(via trigger: SubmitTrigger) {
        guard !instruction.isEmpty else {
            exitEditMode()
            return
        }

        PostHogSDK.shared.capture(
            "instruction_submitted",
            properties: [
                "trigger": trigger.rawValue,
                "length": instruction.count,
                "word_count": instruction.split(separator: " ").count,
                "locale": locale.identifier,
            ]
        )
        generator.generate(
            instruction: instruction,
            into: context,
            locale: locale
        )
        dismiss()
    }

    private func toggleMic() {
        if isListening {
            stopListening()
            return
        }
        if usage.isBlocked {
            PostHogSDK.shared.capture(
                "dictation_blocked_retry",
                properties: ["remaing_minutes": usage.blockRemainingMinutes]
            )
            showMicBlockedAlert = true
            return
        }
        if !transcriber.hasMicPermission {
            showMicPermissionAlert = true
            return
        }
        startListening()
    }

    private func startListening() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isListening = true
        }
        PostHogSDK.shared.capture("dictation_started")
        listenStartedAt = .now
        transcriber.start { instruction = $0 }
        autoCutTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(maxListeningDuration * 1_000_000_000)
            )
            if Task.isCancelled { return }
            PostHogSDK.shared.capture("dictation_autocut_triggered")
            stopListening()
        }
    }

    private func stopListening() {
        autoCutTask?.cancel()
        autoCutTask = nil
        let wasListening = isListening
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isListening = false
        }
        transcriber.stop()
        guard wasListening, let started = listenStartedAt else { return }
        listenStartedAt = nil
        let duration = Date.now.timeIntervalSince(started)
        PostHogSDK.shared.capture(
            "dictation_stopped",
            properties: ["duration_s": Int(duration)]
        )
        let nowBlocked = usage.record(duration: duration)
        if nowBlocked {
            PostHogSDK.shared.capture(
                "dictation_blocked",
                properties: ["remaing_minutes": usage.blockRemainingMinutes]
            )
            showMicBlockedAlert = true
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
                            .submitLabel(.done)
                            .multilineTextAlignment(.center)
                            .onChange(of: instruction) { _, new in
                                if new.contains("\n") {
                                    instruction = new.replacingOccurrences(
                                        of: "\n",
                                        with: ""
                                    )
                                    submit(via: .keyboard)
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
                            .onTapGesture {
                                instruction =
                                    placeholderExamples[placeholderIndex].text
                                enterEditMode(via: .label)
                            }
                    } else {
                        Text(instruction)
                            .onTapGesture { enterEditMode(via: .label) }
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
                    if let url = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        openURL(url)
                    }
                }
                Button(
                    "metric_input_sheet.mic_permission.cancel",
                    role: .cancel
                ) {}
            } message: {
                Text("metric_input_sheet.mic_permission.message")
            }
            .alert(
                "metric_input_sheet.mic_blocked.title",
                isPresented: $showMicBlockedAlert
            ) {
                Button("metric_input_sheet.mic_blocked.ok", role: .cancel) {}
            } message: {
                Text(
                    "metric_input_sheet.mic_blocked.message \(usage.blockRemainingMinutes)"
                )
            }
            .onDisappear { stopListening() }
            .trackScreen("MetricCreation")
            .navigationTitle("Add a tracker").navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { submit(via: .toolbar) }) {
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
        .opacity(usage.isBlocked ? 0.4 : 1)
    }

    private var keyboardButton: some View {
        Button(action: {
            isEditing ? exitEditMode() : enterEditMode(via: .keyboard)
        }) {
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
