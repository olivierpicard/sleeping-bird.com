//
//  AudioCaptureManager.swift
//  SleepingBird
//
//  Created by Olivier Picard on 16/04/2026.
//

import AVFoundation

/// Captures microphone audio as PCM data chunks ready for WebSocket transmission.
@Observable
final class AudioCaptureManager {
    private let audioEngine = AVAudioEngine()
    private(set) var isCapturing = false

    /// Called on a background thread each time a new audio chunk is available.
    /// The Data contains 16-bit mono PCM at 16 kHz.
    var onAudioData: ((Data) -> Void)?

    // MARK: - Target format for transmission
    private static let targetSampleRate: Double = 16_000
    private static let targetChannelCount: AVAudioChannelCount = 1

    // MARK: - Public API

    func startCapturing() async throws {
        guard !isCapturing else { return }

        // Request microphone permission first
        let permitted = await AVAudioApplication.requestRecordPermission()
        guard permitted else {
            throw AudioCaptureError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker]
        )
        try session.setActive(true)

        // Reset the engine to ensure a clean state after permission is granted
        audioEngine.reset()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw AudioCaptureError.formatCreationFailed
        }

        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: Self.targetSampleRate,
                channels: Self.targetChannelCount,
                interleaved: true
            )
        else {
            throw AudioCaptureError.formatCreationFailed
        }

        guard
            let converter = AVAudioConverter(
                from: inputFormat,
                to: targetFormat
            )
        else {
            throw AudioCaptureError.formatCreationFailed
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, _ in
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
            converter.convert(to: convertedBuffer, error: &error) {
                _,
                outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if error != nil { return }

            if let audioData = convertedBuffer.audioBufferList.pointee.mBuffers
                .mData
            {
                let byteCount = Int(
                    convertedBuffer.audioBufferList.pointee.mBuffers
                        .mDataByteSize
                )
                self?.onAudioData?(Data(bytes: audioData, count: byteCount))
            }
        }

        try audioEngine.start()
        isCapturing = true
    }

    func stopCapturing() {
        guard isCapturing else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        isCapturing = false

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

}

enum AudioCaptureError: Error {
    case formatCreationFailed
    case permissionDenied
}
