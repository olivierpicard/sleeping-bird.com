//
//  AIGlowBorderMockup.swift
//  ArperBird
//
//  A UI-testing mockup for a Siri-style, light-emitting glow border.
//
//  The "it emits light" illusion is built from four ingredients:
//    1. An animated multi-color `MeshGradient` as the color source.
//    2. That gradient masked to a thin border *shape* (so it hugs the component).
//    3. Several copies of that border stacked from sharp → very blurry (the halo).
//    4. Additive blending (`.plusLighter`) so overlapping layers brighten, like real light.
//
//  Everything is flattened with `.drawingGroup()` so the blur stack renders on the GPU.
//
//  This is a mockup for UI iteration only — no production wiring. It is intentionally
//  structured (config struct + generic shape + view modifier) so it can grow into a
//  real component later.
//

import SwiftUI

// MARK: - Configuration

/// Tunable knobs for the glow. Everything visual lives here so the look can be
/// iterated without touching the rendering code.
@available(iOS 18.0, *)
struct GlowBorderMockupConfiguration {

    /// One soft, blurred copy of the border. Stacking several of these — from a
    /// tight bright layer to a wide dim one — is what produces the falloff halo.
    struct GlowLayer {
        /// Stroke width for this layer (points).
        var lineWidth: CGFloat
        /// Gaussian blur radius (points). Bigger = softer, wider halo.
        var blur: CGFloat
        /// Layer brightness. Wide layers should be dim.
        var opacity: Double
    }

    /// Colors distributed across the mesh. Loops so there is no visible seam.
    /// Siri-ish palettes are a few very saturated hues, not a full rainbow.
    var colors: [Color]

    /// The sharp, near-white "light source" stroke drawn on top of the halo.
    var coreLineWidth: CGFloat
    var coreColor: Color

    /// The halo, ordered widest/dimmest first so the bright layers land on top.
    var glowLayers: [GlowLayer]

    /// How fast the color field drifts. Slow reads as "alive"; fast reads as a spinner.
    var animationSpeed: Double

    /// Extra hue drift per second, layered on top of the point motion for shimmer.
    var hueDrift: Double

    /// When false the mesh holds still (cheaper; good for static screenshots).
    var animated: Bool

    /// A calm, saturated Siri-like preset.
    static let siri = GlowBorderMockupConfiguration(
        colors: [
            .init(red: 0.98, green: 0.30, blue: 0.62), // pink
            .init(red: 0.60, green: 0.30, blue: 0.98), // violet
            .init(red: 0.30, green: 0.52, blue: 1.00), // blue
            .init(red: 0.20, green: 0.85, blue: 0.98), // cyan
            .init(red: 0.65, green: 0.40, blue: 1.00), // indigo
        ],
        coreLineWidth: 1.5,
        coreColor: .white.opacity(0.9),
        glowLayers: [
            .init(lineWidth: 10, blur: 28, opacity: 0.55), // wide, dim halo
            .init(lineWidth: 6,  blur: 14, opacity: 0.75),
            .init(lineWidth: 3,  blur: 6,  opacity: 0.95), // tight, bright core-adjacent
        ],
        animationSpeed: 0.6,
        hueDrift: 12,
        animated: true
    )
}

// MARK: - Glow border view

/// Draws the emissive border around any `InsettableShape` (rounded rect, capsule, …).
/// Overlay it on a component and match the shape to the component's outline.
@available(iOS 18.0, *)
struct GlowBorderMockup<S: InsettableShape>: View {
    var shape: S
    var configuration: GlowBorderMockupConfiguration = .siri

    var body: some View {
        TimelineView(.animation(paused: !configuration.animated)) { context in
            let time = context.date.timeIntervalSinceReferenceDate * configuration.animationSpeed

            ZStack {
                // Halo: soft, blurred, additively blended copies of the border.
                ForEach(Array(configuration.glowLayers.enumerated()), id: \.offset) { _, layer in
                    borderMesh(time: time, lineWidth: layer.lineWidth)
                        .blur(radius: layer.blur)
                        .opacity(layer.opacity)
                        .blendMode(.plusLighter)
                }

                // Core: the sharp "light source" itself.
                shape
                    .strokeBorder(configuration.coreColor, lineWidth: configuration.coreLineWidth)
                    .blendMode(.plusLighter)
            }
            // Flatten the blur stack onto the GPU and isolate the additive blending
            // so it brightens within the effect, then composites normally.
            .drawingGroup()
            .allowsHitTesting(false)
        }
    }

    /// The animated mesh gradient, masked down to a stroke of the shape.
    private func borderMesh(time: Double, lineWidth: CGFloat) -> some View {
        AnimatedMesh(colors: configuration.colors, time: time, hueDrift: configuration.hueDrift)
            .mask {
                shape.strokeBorder(.white, lineWidth: lineWidth)
            }
    }
}

// MARK: - Animated mesh gradient

/// A 3×3 `MeshGradient` whose edge/center control points drift on sine waves.
/// Corners stay pinned so the mesh always covers the frame (no gaps).
@available(iOS 18.0, *)
private struct AnimatedMesh: View {
    var colors: [Color]
    var time: Double
    var hueDrift: Double

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: points(time),
            colors: meshColors()
        )
        .hueRotation(.degrees(time * hueDrift))
    }

    /// 9 vertices for the 3×3 grid. Corners fixed; mid-edge points slide along
    /// their edge; the center wanders freely.
    private func points(_ t: Double) -> [SIMD2<Float>] {
        let tt = Float(t)
        func wobble(_ base: Float, _ amp: Float, _ phase: Float) -> Float {
            base + amp * sin(tt + phase)
        }
        return [
            SIMD2(0, 0),
            SIMD2(wobble(0.5, 0.18, 0.0), 0),
            SIMD2(1, 0),

            SIMD2(0, wobble(0.5, 0.18, 1.3)),
            SIMD2(wobble(0.5, 0.12, 2.1), wobble(0.5, 0.12, 0.7)),
            SIMD2(1, wobble(0.5, 0.18, 3.4)),

            SIMD2(0, 1),
            SIMD2(wobble(0.5, 0.18, 4.2), 1),
            SIMD2(1, 1),
        ]
    }

    /// Fill 9 vertices by cycling the palette so it loops seamlessly.
    private func meshColors() -> [Color] {
        guard !colors.isEmpty else { return Array(repeating: .white, count: 9) }
        return (0..<9).map { colors[$0 % colors.count] }
    }
}

// MARK: - Convenience modifier

@available(iOS 18.0, *)
extension View {
    /// Wraps the view in a rounded-rect emissive glow border.
    /// - Parameter isActive: fade the whole effect in/out (e.g. on focus).
    func glowBorderMockup(
        cornerRadius: CGFloat,
        configuration: GlowBorderMockupConfiguration = .siri,
        isActive: Bool = true
    ) -> some View {
        overlay {
            GlowBorderMockup(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                configuration: configuration
            )
            .opacity(isActive ? 1 : 0)
            .animation(.easeInOut(duration: 0.35), value: isActive)
        }
    }
}

// MARK: - Preview

@available(iOS 18.0, *)
#Preview("AI Glow Border — text field") {
    struct Demo: View {
        @State private var text = ""
        @State private var isActive = true
        @FocusState private var focused: Bool

        private let cornerRadius: CGFloat = 16

        var body: some View {
            ZStack {
                // The effect always reads best on a dark surface — additive light
                // needs something to add to.
                Color.black.ignoresSafeArea()

                VStack(spacing: 40) {
                    Text("Ask ArperBird")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    TextField("", text: $text, prompt: Text("What do you want to track?")
                        .foregroundColor(.white.opacity(0.4)))
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .focused($focused)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.white.opacity(0.06))
                        }
                        .glowBorderMockup(cornerRadius: cornerRadius, isActive: isActive)
                        .padding(.horizontal, 32)

                    Toggle("Glow active", isOn: $isActive)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 32)
                }
            }
//            .preferredC olorScheme(.dark)
        }
    }
   
    return Demo()
}
