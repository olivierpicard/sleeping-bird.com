//
//  Transcribe.swift
//  SleepingBird
//
//  Created by Olivier Picard on 16/04/2026.
//

import Foundation
import ArkanaKeys

/// Streams microphone audio to Deepgram and forwards transcript text as it arrives.
///
/// Usage:
/// ```swift
/// let t = Transcribe()
/// t.start { text in state = text }
/// t.stop()
/// ```
final class Transcribe {

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

    // MARK: - Init

    init(config: Config = .default) {
        self.config = config
    }

    // MARK: - Public API

    func start(onText: @escaping (String) -> Void) {
        self.onText = onText

        // Connect WebSocket with auth header
        var request = URLRequest(url: config.endpoint)
        request.setValue(
            "Token \(config.apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        
        print(request.value(forHTTPHeaderField: "Authorization") ?? "no value")
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
            let transcript = json["transcript"] as? String,
            !transcript.isEmpty
        else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onText?(transcript)
        }
    }
}
