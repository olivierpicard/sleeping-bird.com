import SwiftUI

struct ReactiveMeshBorder: View {
    let magnitudes: [Float]

    // Geometry
    var cornerRadius: CGFloat = 44
    /// Number of sample points placed around the perimeter.
    var sampleCount: Int = 140

    // Frequency bands
    /// How many bands to extract from magnitudes. Fewer = broader, smoother bands.
    var bandCount: Int = 24

    // Blob shape
    /// Baseline blob radius when silent — keeps the border always visible.
    var minBlobRadius: CGFloat = 5
    /// Peak blob radius at full volume.
    var maxBlobRadius: CGFloat = 25
    /// How far the blob center is pushed inward from the edge (fraction of blob radius).
    var blobInwardFactor: CGFloat = 0.4

    // Visual
    var blurRadius: CGFloat = 20
    /// Minimum effective magnitude applied in the canvas, even at true silence.
    /// Prevents blobs from collapsing below the blur radius and disappearing.
    var magnitudeFloor: Double = 0.1
    /// Opacity of each blob at silence.
    var minOpacity: Double = 1
    /// Opacity of each blob at peak volume.
    var maxOpacity: Double = 0.2

    // Animation
    /// Lerp factor per frame. Lower = slower/smoother, less jitter.
    var smoothing: Float = 0.07

    @Environment(\.colorScheme) private var colorScheme
    @State private var smoothed: [Float] = Array(repeating: 0, count: 24)

    private var palette: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0x4a / 255, green: 0x55 / 255, blue: 0xc8 / 255),
                Color(red: 0xa1 / 255, green: 0xb7 / 255, blue: 0xf6 / 255),
                Color(red: 0xc2 / 255, green: 0x5d / 255, blue: 0xdd / 255),
            ]
        } else {
            return [
                Color(red: 0x64 / 255, green: 0x6c / 255, blue: 0xf6 / 255),
                Color(red: 0xc2 / 255, green: 0x5d / 255, blue: 0xdd / 255),
                Color(red: 0xa1 / 255, green: 0xb7 / 255, blue: 0xf6 / 255),
            ]
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate)
            let bands5 = fiveBands(from: smoothed)
            let energy = smoothed.reduce(0, +) / Float(smoothed.count)
            let sm = smoothed

            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints(t: t, bands: bands5),
                colors: meshColors(energy: energy)
            )
            .blur(radius: blurRadius)
            .mask {
                Canvas { ctx, size in
                    let n = sampleCount
                    for i in 0..<n {
                        let progress = Double(i) / Double(n)
                        let bandIdx = Int(progress * Double(sm.count)) % max(sm.count, 1)
                        let mag = max(magnitudeFloor, Double(sm.isEmpty ? 0 : sm[bandIdx]))
                        let blobR = CGFloat(
                            Double(minBlobRadius) + mag * Double(maxBlobRadius - minBlobRadius)
                        )
                        let (pt, nrm) = perimeterPoint(
                            t: progress, size: size, cornerRadius: cornerRadius
                        )
                        let cx = pt.x + nrm.dx * blobR * Double(blobInwardFactor)
                        let cy = pt.y + nrm.dy * blobR * Double(blobInwardFactor)
                        let opacity = minOpacity + (maxOpacity - minOpacity) * mag
                        ctx.fill(
                            Path(ellipseIn: CGRect(
                                x: cx - blobR, y: cy - blobR,
                                width: blobR * 2, height: blobR * 2
                            )),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }
                .blur(radius: blurRadius * 0.5)
            }
            .onChange(of: context.date) { _, _ in tickSmoothing() }
        }
        .allowsHitTesting(false)
    }

    private func tickSmoothing() {
        guard !magnitudes.isEmpty else { return }
        let n = max(1, min(bandCount, magnitudes.count))
        if smoothed.count != n {
            smoothed = Array(repeating: 0, count: n)
        }
        let src = magnitudes.count
        for i in 0..<n {
            // Average the magnitudes slice that maps to this band
            let lo = i * src / n
            let hi = max(lo + 1, (i + 1) * src / n)
            let slice = magnitudes[lo..<min(hi, src)]
            let target = min(1, slice.reduce(0, +) / Float(slice.count) * 1.3)
            smoothed[i] += (target - smoothed[i]) * smoothing
        }
    }

    private func fiveBands(from values: [Float]) -> [Float] {
        guard !values.isEmpty else { return Array(repeating: 0, count: 5) }
        let count = values.count
        return (0..<5).map { b in
            let lo = b * count / 5
            let hi = max(lo + 1, (b + 1) * count / 5)
            let slice = values[lo..<min(hi, count)]
            return slice.reduce(0, +) / Float(slice.count)
        }
    }

    private func meshPoints(t: Float, bands: [Float]) -> [SIMD2<Float>] {
        let drift = sin(t * 0.6) * 0.04
        let drift2 = cos(t * 0.45) * 0.04
        let (bass, lowMid, mid, highMid, treble) =
            (bands[0], bands[1], bands[2], bands[3], bands[4])
        return [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(0.5 + drift2 + (treble - 0.5) * 0.18, 0),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(0, 0.5 + drift + (lowMid - 0.5) * 0.18),
            SIMD2<Float>(0.5 + (mid - 0.5) * 0.22 + drift, 0.5 + (mid - 0.5) * 0.22 + drift2),
            SIMD2<Float>(1, 0.5 - drift + (highMid - 0.5) * 0.18),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(0.5 - drift2 + (bass - 0.5) * 0.18, 1),
            SIMD2<Float>(1, 1),
        ]
    }

    private func meshColors(energy: Float) -> [Color] {
        let p = palette
        let o = Double(0.28 + min(0.65, energy * 1.6))
        return [
            p[0].opacity(o), p[1].opacity(o), p[2].opacity(o),
            p[1].opacity(o), p[0].opacity(o * 0.9), p[2].opacity(o),
            p[2].opacity(o), p[0].opacity(o), p[1].opacity(o),
        ]
    }
}

// Walks the rounded-rect perimeter at normalized t ∈ [0, 1),
// returning the surface point and inward unit normal.
private func perimeterPoint(
    t: Double, size: CGSize, cornerRadius: CGFloat
) -> (CGPoint, CGVector) {
    let r = Double(min(cornerRadius, min(size.width, size.height) / 2))
    let w = Double(size.width)
    let h = Double(size.height)

    let arcLen = Double.pi / 2 * r
    let topLen = w - 2 * r
    let rightLen = h - 2 * r
    let bottomLen = w - 2 * r
    let leftLen = h - 2 * r
    let total = topLen + arcLen + rightLen + arcLen + bottomLen + arcLen + leftLen + arcLen

    var d = t.truncatingRemainder(dividingBy: 1.0) * total

    if d < topLen {
        return (CGPoint(x: r + d, y: 0), CGVector(dx: 0, dy: 1))
    }
    d -= topLen

    if d < arcLen {
        return roundedCorner(d / arcLen, r: r, cx: w - r, cy: r, a0: -.pi / 2, a1: 0)
    }
    d -= arcLen

    if d < rightLen {
        return (CGPoint(x: w, y: r + d), CGVector(dx: -1, dy: 0))
    }
    d -= rightLen

    if d < arcLen {
        return roundedCorner(d / arcLen, r: r, cx: w - r, cy: h - r, a0: 0, a1: .pi / 2)
    }
    d -= arcLen

    if d < bottomLen {
        return (CGPoint(x: w - r - d, y: h), CGVector(dx: 0, dy: -1))
    }
    d -= bottomLen

    if d < arcLen {
        return roundedCorner(d / arcLen, r: r, cx: r, cy: h - r, a0: .pi / 2, a1: .pi)
    }
    d -= arcLen

    if d < leftLen {
        return (CGPoint(x: 0, y: h - r - d), CGVector(dx: 1, dy: 0))
    }
    d -= leftLen

    return roundedCorner(min(1, d / arcLen), r: r, cx: r, cy: r, a0: .pi, a1: 1.5 * .pi)
}

private func roundedCorner(
    _ progress: Double, r: Double, cx: Double, cy: Double, a0: Double, a1: Double
) -> (CGPoint, CGVector) {
    let angle = a0 + progress * (a1 - a0)
    let px = cx + r * cos(angle)
    let py = cy + r * sin(angle)
    return (
        CGPoint(x: px, y: py),
        CGVector(dx: -cos(angle), dy: -sin(angle))  // inward = toward arc center
    )
}

private struct ReactiveMeshBorderPreviewHost: View {
    @State private var vm: SpectrumViewModel = FakeSpectrumViewModel()
    var body: some View {
        ReactiveMeshBorder(magnitudes: vm.magnitudes)
            .ignoresSafeArea()
            .task { vm.start() }
    }
}

#Preview("Reactive border — fake audio") {
    ReactiveMeshBorderPreviewHost()
}
