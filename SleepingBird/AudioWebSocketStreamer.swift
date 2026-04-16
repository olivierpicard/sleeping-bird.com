//
//  AudioWebSocketStreamer.swift
//  SleepingBird
//
//  Created by Olivier Picard on 16/04/2026.
//

import Foundation

/// Streams raw audio `Data` chunks over a WebSocket connection.
/// Designed to work with `AudioCaptureManager.onAudioData`.
@Observable
final class AudioWebSocketStreamer {
    private(set) var isConnected = false

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession

    /// Called when a message is received from the server.
    var onMessageReceived: ((URLSessionWebSocketTask.Message) -> Void)?

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Connection

    func connect(to url: URL) {
        disconnect()
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        isConnected = true
        listenForMessages()
    }

    func connect(with request: URLRequest) {
        disconnect()
        let task = session.webSocketTask(with: request)
        webSocketTask = task
        task.resume()
        isConnected = true
        listenForMessages()
    }

    func disconnect() {
        guard isConnected else { return }
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - Sending audio data

    /// Sends a raw audio data chunk as a WebSocket binary message.
    /// Intended to be passed directly as `AudioCaptureManager.onAudioData`.
    func send(_ audioData: Data) {
        guard isConnected, let task = webSocketTask else { return }
        let message = URLSessionWebSocketTask.Message.data(audioData)
        task.send(message) { [weak self] error in
            if let error {
                print("WebSocket send error: \(error.localizedDescription)")
                self?.handleConnectionLost()
            }
        }
    }

    // MARK: - Receiving (keep-alive / server messages)

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self, self.isConnected else { return }
            switch result {
            case .success(let message):
                self.onMessageReceived?(message)
                self.listenForMessages()
            case .failure(let error):
                print("WebSocket receive error: \(error.localizedDescription)")
                self.handleConnectionLost()
            }
        }
    }

    // MARK: - Helpers

    private func handleConnectionLost() {
        webSocketTask = nil
        isConnected = false
    }
}
