//
//  SpectrumViewModel.swift
//  SleepingBird
//

import Foundation

protocol SpectrumViewModel {
    var magnitudes: [Float] { get set }
    func start()
    func stop()
}

@Observable
final class LiveSpectrumViewModel: SpectrumViewModel {
    var magnitudes: [Float]

    private let analyzer: SpectrumAnalyzer
    private let broker = MicBroker.shared
    private var token: UUID?

    init(bandCount: Int = 24, fftLength: Int = 512) {
        self.analyzer = SpectrumAnalyzer(
            bandCount: bandCount,
            fftLength: fftLength
        )
        self.magnitudes = Array(repeating: 0, count: bandCount)
    }

    func start() {
        guard token == nil else { return }
        token = broker.subscribe { [weak self] data in
            guard let self else { return }
            let next = self.analyzer.process(pcmInt16: data)
            Task { @MainActor in self.magnitudes = next }
        }
    }

    func stop() {
        if let token { broker.unsubscribe(token) }
        token = nil
    }
}

@Observable
final class FakeSpectrumViewModel: SpectrumViewModel {
    var magnitudes: [Float]

    private let bandCount: Int
    private var timer: Timer?
    private var tick: Int = 0

    init(bandCount: Int = 24) {
        self.bandCount = bandCount
        self.magnitudes = Array(repeating: 0, count: bandCount)
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tick &+= 1
            self.magnitudes = self.nextFrame()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        magnitudes = Array(repeating: 0, count: bandCount)
    }

    private func nextFrame() -> [Float] {
        // Simulate speech: bursts of activity (talking) and quiet gaps (pauses).
        // Cycle ~6s: 4s talking, 2s silent.
        let phase = Float(tick % 120) / 120
        let isTalking = phase < 0.66
        let envelope: Float = isTalking ? (0.5 + 0.5 * sin(phase * 18)) : 0.05

        return (0..<bandCount).map { i in
            let t = Float(tick) * 0.1
            let bandBias = sin(Float(i) * 0.4 + t) * 0.3 + 0.6
            let noise = Float.random(in: 0...1)
            let value = envelope * bandBias * noise
            return min(max(value, 0), 1)
        }
    }
}
