//
//  MicBroker.swift
//  ArperBird
//

import AVFoundation
import Foundation

/// Owns the microphone tap and fans out PCM buffers to multiple subscribers.
/// Buffers are 16-bit mono PCM at 16 kHz (interleaved Int16) so consumers
/// can either stream them straight to a transcription WebSocket or convert
/// to Float for analysis (FFT, RMS, etc.).
@Observable
final class MicBroker {
    static let shared = MicBroker()

    private init() {}

    private let audioEngine = AVAudioEngine()
    private let queue = DispatchQueue(label: "com.alizetech.arperbird.micbroker")
    private var handlers: [UUID: (Data) -> Void] = [:]
    private var isRunning = false

    private static let targetSampleRate: Double = 16_000
    private static let targetChannelCount: AVAudioChannelCount = 1

    /// Whether the user has granted microphone recording permission.
    /// Keeps `AVFoundation` permission APIs contained within `MicBroker`;
    /// other layers consult this Bool rather than touching `AVAudioApplication`.
    var hasPermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    /// Subscribe to PCM buffers. The handler runs on a background audio thread.
    /// Returns a token used to `unsubscribe`.
    @discardableResult
    func subscribe(_ handler: @escaping (Data) -> Void) -> UUID {
        let token = UUID()
        queue.sync { handlers[token] = handler }
        Task { await startIfNeeded() }
        return token
    }

    func unsubscribe(_ token: UUID) {
        let shouldStop: Bool = queue.sync {
            handlers.removeValue(forKey: token)
            return handlers.isEmpty
        }
        if shouldStop { stop() }
    }

    // MARK: - Engine lifecycle

    private func startIfNeeded() async {
        let alreadyRunning = queue.sync { isRunning }
        if alreadyRunning { return }

        let permitted = await AVAudioApplication.requestRecordPermission()
        guard permitted else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker]
            )
            try session.setActive(true)

            audioEngine.reset()

            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0 else { return }

            guard
                let targetFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: Self.targetSampleRate,
                    channels: Self.targetChannelCount,
                    interleaved: true
                ),
                let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            else { return }

            inputNode.installTap(
                onBus: 0,
                bufferSize: 4096,
                format: inputFormat
            ) { [weak self] buffer, _ in
                guard let self else { return }

                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * Self.targetSampleRate
                        / inputFormat.sampleRate
                )
                guard
                    let convertedBuffer = AVAudioPCMBuffer(
                        pcmFormat: targetFormat,
                        frameCapacity: frameCapacity
                    )
                else { return }

                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                if error != nil { return }

                guard
                    let raw = convertedBuffer.audioBufferList.pointee.mBuffers.mData
                else { return }
                let byteCount = Int(
                    convertedBuffer.audioBufferList.pointee.mBuffers.mDataByteSize
                )
                let data = Data(bytes: raw, count: byteCount)
                self.fanout(data)
            }

            try audioEngine.start()
            queue.sync { isRunning = true }
        } catch {
            return
        }
    }

    private func stop() {
        let wasRunning: Bool = queue.sync {
            let was = isRunning
            isRunning = false
            return was
        }
        guard wasRunning else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func fanout(_ data: Data) {
        let snapshot: [(Data) -> Void] = queue.sync { Array(handlers.values) }
        for handler in snapshot { handler(data) }
    }
}
