//
//  DeepgramNova3Transcriber.swift
//  SleepingBird
//
//  Created by Olivier Picard on 17/04/2026.
//

import ArkanaKeys
import Foundation

/// Streams microphone audio to Deepgram nova-3 and forwards transcript text as it arrives.
/// Supports both interim and final results.
///
/// Usage:
/// ```swift
/// let t = DeepgramNova3Transcriber()
/// t.start { text in state = text }
/// t.stop()
/// ```
final class DeepgramNova3Transcriber: Transcriber {

    // MARK: - Configuration

    struct Config {
        var apiKey: String
        var endpoint: URL
        /// When `true`, the `onText` callback fires for interim results too.
        /// When `false`, only final (committed) transcripts are delivered.
        var interimResults: Bool

        static let `default` = Config(
            apiKey: ArkanaKeys.Global().deepgramApiKey,
            endpoint: URL(
                string:
                    "wss://api.deepgram.com/v1/listen?endpointing=10&interim_results=true&smart_format=true&language=multi&model=nova-3&encoding=linear16&sample_rate=16000"
            )!,
            interimResults: true
        )
    }

    // MARK: - Private state

    private let config: Config
    private let capture = AudioCaptureManager()
    private let streamer = AudioWebSocketStreamer()
    private var onText: ((String) -> Void)?

    /// All finalized (`is_final`) transcript segments accumulated since `start()`.
    private var committedText = ""
    /// The latest interim transcript for the in-progress utterance (not yet finalized).
    private var interimText = ""

    // MARK: - Init

    init(config: Config = .default) {
        self.config = config
    }

    // MARK: - Transcriber

    func start(onText: @escaping (String) -> Void) {
        self.onText = onText
        committedText = ""
        interimText = ""

        var request = URLRequest(url: config.endpoint)
        request.setValue(
            "Token \(config.apiKey)",
            forHTTPHeaderField: "Authorization"
        )

        streamer.connect(with: request)

        capture.onAudioData = { [weak self] data in
            self?.streamer.send(data)
        }

        streamer.onMessageReceived = { [weak self] message in
            self?.handleMessage(message)
        }

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

    /// Nova-3 response shape:
    /// ```json
    /// {
    ///   "is_final": true,
    ///   "channel": { "alternatives": [{ "transcript": "hello world" }] }
    /// }
    /// ```
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
            let json = try? JSONSerialization.jsonObject(with: jsonData)
                as? [String: Any],
            let channel = json["channel"] as? [String: Any],
            let alternatives = channel["alternatives"] as? [[String: Any]],
            let transcript = alternatives.first?["transcript"] as? String,
            !transcript.isEmpty
        else { return }

        let isFinal = json["is_final"] as? Bool ?? false

        if isFinal {
            committedText =
                committedText.isEmpty
                ? transcript : committedText + " " + transcript
            interimText = ""
        } else {
            guard config.interimResults else { return }
            interimText = transcript
        }

        let fullText =
            interimText.isEmpty
            ? committedText
            : committedText + (committedText.isEmpty ? "" : " ") + interimText

        DispatchQueue.main.async { [weak self] in
            print("final: \(isFinal) --- Full text: \(fullText)")
            self?.onText?(fullText)
        }
    }
}
