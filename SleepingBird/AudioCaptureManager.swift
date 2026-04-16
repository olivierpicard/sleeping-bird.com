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

    private let converterNode = AVAudioMixerNode()
    private let sinkNode = AVAudioMixerNode()

    // MARK: - Public API

    func startCapturing() throws {
        guard !isCapturing else { return }

        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, options: [.allowBluetoothHFP])
            try session.setActive(true)
        #endif

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

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

        audioEngine.attach(converterNode)
        audioEngine.attach(sinkNode)

        audioEngine.connect(inputNode, to: converterNode, format: inputFormat)
        audioEngine.connect(converterNode, to: sinkNode, format: targetFormat)

        converterNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: targetFormat
        ) { [weak self] buffer, _ in
            let audioBuffer = buffer.audioBufferList.pointee.mBuffers
            if let data = audioBuffer.mData {
                self?.onAudioData?(
                    Data(bytes: data, count: Int(audioBuffer.mDataByteSize))
                )
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isCapturing = true
    }

    func stopCapturing() {
        guard isCapturing else { return }
        converterNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.detach(converterNode)
        audioEngine.detach(sinkNode)
        isCapturing = false

        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        #endif
    }

}

enum AudioCaptureError: Error {
    case formatCreationFailed
}
