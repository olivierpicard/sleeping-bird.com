//
//  Transcribe.swift
//  SleepingBird
//
//  Created by Olivier Picard on 16/04/2026.
//

import Foundation
import ArkanaKeys



// MARK: - Deepgram implementation

/// Streams microphone audio to Deepgram and forwards transcript text as it arrives.
///
/// Usage:
/// ```swift
/// let t = DeepgramFluxTranscriber()
/// t.start { text in state = text }
/// t.stop()
/// ```
final class DeepgramFluxTranscriber: Transcriber {

    // MARK: - Configuration

    struct Config {
        var apiKey: String
        var endpoint: URL

        static let `default` = Config(
            apiKey: ArkanaKeys.Global().deepgramApiKey,
            endpoint: URL(
                string:
                    "wss://api.deepgram.com/v2/listen?eot_threshold=0.7&eot_timeout_ms=5000&model=flux-general-multi&encoding=linear16&sample_rate=16000"
            )!
        )
    }

    // MARK: - Private state

    private let config: Config
    private let capture = AudioCaptureManager()
    private let streamer = AudioWebSocketStreamer()
    private var onText: ((String) -> Void)?

    /// All fully committed turns (EndOfTurn) accumulated since `start()`.
    private var committedText = ""
    /// The running transcript for the current in-progress turn.
    private var interimText = ""

    // MARK: - Init

    init(config: Config = .default) {
        self.config = config
    }

    // MARK: - Public API

    func start(onText: @escaping (String) -> Void) {
        self.onText = onText
        committedText = ""
        interimText = ""

        // Connect WebSocket with auth header
        var request = URLRequest(url: config.endpoint)
        request.setValue(
            "Token \(config.apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        
        streamer.connect(with: request)

        // Forward audio chunks to WebSocket
        capture.onAudioData = { [weak self] data in
            self?.streamer.send(data)
        }

        // Parse transcripts from server messages
        streamer.onMessageReceived = { [weak self] message in
            self?.handleMessage(message)
        }

        // Start microphone
        Task {
            try? await capture.startCapturing()
        }
    }

    func stop() {
        capture.stopCapturing()
        streamer.disconnect()
        onText = nil
    }

    // MARK: - Message parsing

    /// Flux v2 response shape:
    /// ```json
    /// { "event": "Update"|"StartOfTurn"|"EagerEndOfTurn"|"TurnResumed"|"EndOfTurn",
    ///   "turn_index": 0,
    ///   "transcript": "hello world" }
    /// ```
    /// `transcript` is the **full** running text for the current turn on every event,
    /// not a delta. It is committed to history only on `EndOfTurn`.
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let jsonData: Data?
        switch message {
        case .string(let text):
            jsonData = text.data(using: .utf8)
        case .data(let data):
            jsonData = data
        @unknown default:
            return
        }

        guard
            let jsonData,
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return }

        let event = json["event"] as? String ?? ""
        let transcript = json["transcript"] as? String ?? ""

        switch event {
        case "EndOfTurn":
            // Commit the final transcript for this turn
            if !transcript.isEmpty {
                committedText = committedText.isEmpty ? transcript : committedText + " " + transcript
            }
            interimText = ""
        case "StartOfTurn", "Update", "EagerEndOfTurn", "TurnResumed":
            // transcript is the full running text for the current turn
            interimText = transcript
        default:
            return
        }

        let fullText = interimText.isEmpty
            ? committedText
            : committedText + (committedText.isEmpty ? "" : " ") + interimText

        guard !fullText.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onText?(fullText)
        }
    }
}
