//
//  SpectrumAnalyzer.swift
//  ArperBird
//

import Accelerate
import Foundation

final class SpectrumAnalyzer {
    private let bandCount: Int
    private let fftLength: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let window: [Float]

    private var smoothed: [Float]
    private let smoothing: Float = 0.7

    init(bandCount: Int, fftLength: Int) {
        precondition(fftLength.nonzeroBitCount == 1, "fftLength must be a power of two")
        self.bandCount = bandCount
        self.fftLength = fftLength
        self.log2n = vDSP_Length(log2(Float(fftLength)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        var win = [Float](repeating: 0, count: fftLength)
        vDSP_hann_window(&win, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
        self.window = win

        self.smoothed = [Float](repeating: 0, count: bandCount)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Convert Int16 PCM bytes → Float, run FFT, bucket into bands, smooth.
    func process(pcmInt16: Data) -> [Float] {
        let sampleCount = pcmInt16.count / MemoryLayout<Int16>.size
        guard sampleCount >= fftLength else { return smoothed }

        var floats = [Float](repeating: 0, count: fftLength)
        pcmInt16.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.bindMemory(to: Int16.self).baseAddress else { return }
            // Use the most recent fftLength samples
            let offset = sampleCount - fftLength
            vDSP_vflt16(base.advanced(by: offset), 1, &floats, 1, vDSP_Length(fftLength))
        }
        var scale: Float = 1.0 / 32_768.0
        vDSP_vsmul(floats, 1, &scale, &floats, 1, vDSP_Length(fftLength))

        // Window
        vDSP_vmul(floats, 1, window, 1, &floats, 1, vDSP_Length(fftLength))

        // Pack to split-complex and FFT in-place
        let halfN = fftLength / 2
        var realp = [Float](repeating: 0, count: halfN)
        var imagp = [Float](repeating: 0, count: halfN)
        var magnitudes = [Float](repeating: 0, count: halfN)

        realp.withUnsafeMutableBufferPointer { rPtr in
            imagp.withUnsafeMutableBufferPointer { iPtr in
                var split = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                floats.withUnsafeBufferPointer { fPtr in
                    fPtr.baseAddress!.withMemoryRebound(
                        to: DSPComplex.self,
                        capacity: halfN
                    ) { cPtr in
                        vDSP_ctoz(cPtr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfN))
            }
        }

        // sqrt + log scale
        var bins = [Float](repeating: 0, count: halfN)
        var count = Int32(halfN)
        vvsqrtf(&bins, magnitudes, &count)

        // Bucket lower half (covers 0–4 kHz which is where speech sits) into bands.
        // Use logarithmic bin grouping for a more musical look.
        let usableBins = halfN
        var bands = [Float](repeating: 0, count: bandCount)
        for b in 0..<bandCount {
            let startFrac = pow(Float(b) / Float(bandCount), 2)
            let endFrac = pow(Float(b + 1) / Float(bandCount), 2)
            let start = max(1, Int(startFrac * Float(usableBins)))
            let end = max(start + 1, Int(endFrac * Float(usableBins)))
            var sum: Float = 0
            for i in start..<min(end, usableBins) { sum += bins[i] }
            let avg = sum / Float(end - start)
            // Compress dynamic range
            bands[b] = min(1, log10(1 + avg * 25) * 0.9)
        }

        // Exponential smoothing toward new values
        for i in 0..<bandCount {
            let prev = smoothed[i]
            let next = bands[i]
            // Rise fast, fall slower
            let alpha: Float = next > prev ? 0.55 : 0.20
            smoothed[i] = prev * (1 - alpha) + next * alpha
        }
        return smoothed
    }
}
