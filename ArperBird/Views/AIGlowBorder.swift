//
//  AIGlowBorder.swift
//  ArperBird
//
//  Created by Olivier Picard on 09/07/2026.
//

import SwiftUI

/// An "Apple Intelligence"–style edge glow for a rounded-rect control: a full
/// spectrum of light hugs the border and **circulates** around it, hues
/// travelling continuously clockwise. Used as the fake-loading beat around the
/// creation field — the field appears to "think" before the sheet opens.
///
/// It's a fork of `ReactiveMeshBorder`'s idea (soft colored blobs walked around
/// a rounded-rect perimeter, then blurred into light), but driven by time
/// instead of audio: the color assigned to each blob slides around the loop, so
/// the whole ring spins.
///
/// **Why a perimeter walk and not an `AngularGradient`.** A conic gradient
/// distributes color by *angle from the center*, so on a wide, short field
/// almost all of its range lands on the long top/bottom edges and the short
/// sides go dark — a "hole" in the ring. Walking the perimeter by *arc length*
/// instead gives every side equal coverage no matter the aspect ratio, and
/// sliding the color offset per frame is what makes the hues travel around.
///
/// Drop it on with `.aiGlowBorder(isActive:cornerRadius:)`.
struct AIGlowBorder: View {
    /// Must match the host control's corner radius so the glow tracks its edge.
    var cornerRadius: CGFloat = 12
    /// Radius of each colored blob before blur — how thick the rim of light reads.
    var blobRadius: CGFloat = 5
    /// How far the light blooms out from the edge. Larger = softer, more
    /// diffuse halo; smaller = crisper.
    var blurRadius: CGFloat = 12
    /// How many blobs are placed around the perimeter. Enough that neighbours
    /// overlap into a continuous ring at `blobRadius`.
    var sampleCount: Int = 180
    /// How far (points) each blob is pushed *outward* off the edge, so the glow
    /// blooms outside the field rather than washing over the text inside. 0 =
    /// centered on the border.
    var outwardBias: CGFloat = 0
    /// A brighter, near-white core drawn inside each blob for "shine" (0…1 =
    /// how far its tint is lifted toward white). 0 = flat color, no highlight.
    var coreShine: Double = 0
    /// Seconds for one full lap of the colors around the border.
    var period: Double = 2.5
    /// Whether the glow gently pulses in intensity. Off = a dead-steady
    /// rotating ring (the color still circulates, but the halo doesn't breathe).
    var breathes: Bool = true
    /// Seconds for one intensity in/out "breath".
    var breathPeriod: Double = 1.8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// The circulating spectrum, matching the reference: blue → indigo → violet
    /// → magenta → red → orange → gold, wrapping back to blue so the loop seam
    /// is invisible. Stored as RGB triples so a blob can be tinted at a
    /// *continuous* position along the loop (interpolated between stops).
    ///
    /// The hues are **brightness-matched**: the darker blues/violets are lifted
    /// and the bright gold tamed so every hue carries roughly equal luminance —
    /// otherwise the ring flares where a bright hue sits and dims where a dark
    /// one does, throbbing as it spins.
    private static let stops: [SIMD3<Double>] = [
        SIMD3(0.40, 0.52, 1.00),  // blue
        SIMD3(0.58, 0.44, 1.00),  // indigo
        SIMD3(0.74, 0.42, 1.00),  // violet
        SIMD3(0.95, 0.42, 0.92),  // magenta
        SIMD3(1.00, 0.40, 0.58),  // pink-red
        SIMD3(1.00, 0.55, 0.32),  // orange
        SIMD3(0.92, 0.52, 0.36),  // gold (tamed)
        SIMD3(0.78, 0.50, 1.00),  // violet (return arc)
    ]

    /// The spectrum RGB at a continuous loop position, wrapping at 1.0 and
    /// lerping between adjacent stops so the ring has no visible bands.
    private static func rgb(at fraction: Double) -> SIMD3<Double> {
        let n = stops.count
        let x = (fraction.truncatingRemainder(dividingBy: 1) + 1)
            .truncatingRemainder(dividingBy: 1) * Double(n)
        let i = Int(x) % n
        let j = (i + 1) % n
        let f = x - Double(Int(x))
        return stops[i] + (stops[j] - stops[i]) * f
    }

    var body: some View {
        // The glow must draw *outside* the field (outward bloom), but `Canvas`
        // clips to its own bounds — so render it into a frame padded by `margin`
        // on every side and slide it back so the field region lines up.
        GeometryReader { geo in
            let sz = geo.size
            let m = blurRadius + max(0, outwardBias) + blobRadius

            // A frame-driven clock so the circulation runs on its own,
            // independent of the animation system, and freezes under Reduce
            // Motion.
            TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                // Normalized [0, 1) offset that slides the colors around the loop.
                let offset = reduceMotion
                    ? 0 : (t / period).truncatingRemainder(dividingBy: 1)
                // Gentle intensity breath so the "thinking" reads alive, not a
                // static decal. Near-full under Reduce Motion or when disabled.
                let breath = (reduceMotion || !breathes)
                    ? 1
                    : 0.82 + 0.18 * (0.5 + 0.5 * sin(t / breathPeriod * 2 * .pi))

                // Walk the field's perimeter placing a spectrum-tinted blob at
                // each step (offset by `m` into the padded canvas). Blobs paint
                // with the canvas's default blend (overwrite), so the ring is an
                // even solid color — the additive glow happens once,
                // layer-vs-field, via `.blendMode`, so overlaps don't blow out.
                Canvas { ctx, _ in
                    let n = sampleCount
                    for i in 0..<n {
                        let p = Double(i) / Double(n)
                        let (pt, nrm) = perimeterPoint(
                            t: p, size: sz, cornerRadius: cornerRadius
                        )
                        // Into padded space (+m), then push *outward* (opposite
                        // the inward normal) so the bloom sits off the edge,
                        // not over the field's text.
                        let cx = pt.x + m - nrm.dx * outwardBias
                        let cy = pt.y + m - nrm.dy * outwardBias
                        let base = Self.rgb(at: p + offset)

                        ctx.fill(
                            blob(cx: cx, cy: cy, r: blobRadius),
                            with: .color(Color(red: base.x, green: base.y, blue: base.z))
                        )
                        // A smaller, whiter core for shine — over the blob, so
                        // the center reads hot and the hue survives at the edges.
                        if coreShine > 0 {
                            let hot = base + (SIMD3(1, 1, 1) - base) * coreShine
                            ctx.fill(
                                blob(cx: cx, cy: cy, r: blobRadius * 0.5),
                                with: .color(Color(red: hot.x, green: hot.y, blue: hot.z))
                            )
                        }
                    }
                }
                .frame(width: sz.width + 2 * m, height: sz.height + 2 * m)
                .blur(radius: blurRadius)
                .opacity(breath)
                // Additive on dark so the hues build into light against a dark
                // field (as in the reference); normal on light, where adding
                // would blow the pastel rim out to white.
                .blendMode(colorScheme == .dark ? .plusLighter : .normal)
                .offset(x: -m, y: -m)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A circle of radius `r` centered at `(cx, cy)`.
    private func blob(cx: Double, cy: Double, r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }
}

extension View {
    /// Overlays the circulating `AIGlowBorder` while `isActive`, fading it in
    /// and out. `cornerRadius` should match the host control so the glow rides
    /// its edge exactly.
    func aiGlowBorder(
        isActive: Bool,
        cornerRadius: CGFloat = 12,
        blobRadius: CGFloat = 5,
        blurRadius: CGFloat = 12,
        outwardBias: CGFloat = 0,
        coreShine: Double = 0,
        breathes: Bool = true
    ) -> some View {
        overlay {
            if isActive {
                AIGlowBorder(
                    cornerRadius: cornerRadius,
                    blobRadius: blobRadius,
                    blurRadius: blurRadius,
                    outwardBias: outwardBias,
                    coreShine: coreShine,
                    breathes: breathes
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isActive)
    }
}

// MARK: - Perimeter walk

/// Walks the rounded-rect perimeter at normalized `t ∈ [0, 1)`, returning the
/// surface point and inward unit normal. Forked from `ReactiveMeshBorder` so the
/// glow stays a self-contained component.
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

// MARK: - Previews

/// The glow around a mock creation field — the context it ships in.
#Preview("AI glow — around a field") {
    struct Demo: View {
        @State private var active = true
        var body: some View {
            VStack(spacing: 40) {
                // A stand-in for the empty-dashboard CTA field.
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                    Text("how many coffees I drink")
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
                .aiGlowBorder(isActive: active, cornerRadius: 12)
                .padding(.horizontal)

                Button(active ? "Stop glow" : "Start glow") {
                    active.toggle()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    return Demo()
}

/// The steady version — colors circulate, but the halo doesn't pulse in size
/// (`breathes: false`). Compare against "around a field" to judge the breath.
#Preview("AI glow — field, no breath") {
    VStack {
        Spacer()
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
            Text("how many coffees I drink")
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .aiGlowBorder(isActive: true, cornerRadius: 12, breathes: false)
        .padding(.horizontal)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

/// Side-by-side: the current glow vs. a brighter, crisper, more-outward tune
/// (`coreShine` for the highlight, less blur, `outwardBias` to push it off the
/// edge). Forced dark so the shine reads.
#Preview("AI glow — bright vs current") {
    struct Field: View {
        let title: String
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(.secondary)
                Text(title).foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
        }
    }
    return VStack(spacing: 72) {
        VStack(spacing: 12) {
            Text("CURRENT").font(.caption2).foregroundStyle(.secondary)
            Field(title: "how many coffees I drink")
                .aiGlowBorder(isActive: true, cornerRadius: 12)
        }
        VStack(spacing: 12) {
            Text("BRIGHTER · CRISP · OUTWARD")
                .font(.caption2).foregroundStyle(.secondary)
            Field(title: "how many coffees I drink")
                .aiGlowBorder(
                    isActive: true,
                    cornerRadius: 12,
                    blobRadius: 5,
                    blurRadius: 10,
                    outwardBias: -2,
                    coreShine: 0.99,
                    
                )
        }
    }
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
//    .background(.black)
//    .environment(\.colorScheme, .dark)
}

/// Full-screen so the circulating spectrum reads clearly, matching the
/// reference image.
#Preview("AI glow — full frame") {
    AIGlowBorder(cornerRadius: 44, blobRadius: 16, blurRadius: 40, sampleCount: 240)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
}
