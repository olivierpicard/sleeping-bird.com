//
//  GlowBorder.swift
//  ArperBird
//
//  A neon "emits light" border for any component — a thin white-hot filament,
//  a colored edge, and a soft bloom whose hues circulate around the shape.
//
//  Production entry point is the `.glowBorder(palette:style:period:)` modifier
//  (and its geometry-taking overload). Three preset knobs cover the intended
//  looks; `GlowBorderStyle` underneath is the fully-tunable config the DEBUG
//  playground (`GlowBorderPlayground`) drives directly.
//
//  How the rendering works, bottom to top:
//    1. One conic `AngularGradient` is the single color source. Every layer
//       strokes the same shape with it, so all layers stay in sync. Rotating
//       the gradient's `angle` over time is what makes the colors circulate.
//    2. The bloom is the same stroked ring repeated with increasing blur
//       (`bloomPasses`). Blur spreads both ways, so the ring is drawn twice:
//       once masked to *outside* the shape (outward leak) and once clipped to
//       *inside* it (inward leak) — which is what makes the two independently
//       tunable.
//    3. The edge line sits on top. Its intensity dims it below 1, and above 1
//       a thinner pure-white stroke fades in over the colored one, so an
//       overdriven edge burns white in the middle while keeping colored fringes.
//

import SwiftUI

// MARK: - Public API

/// Color theme for the glow. The hues circulate around the shape; the *gaps*
/// between stop locations are the spreading (bunch two for a sharp transition,
/// spread them for a slow wash).
enum GlowPalette {
    /// Pink → orange hotspot → blues/cyan → violet. The reference look.
    case neon
    /// Warm gold most of the lap, easing through a cool blue band on top.
    case ember
    /// Cool blues and violet with a pink right side and a gold hotspot.
    case nocturn
    /// Violet anchor with a warm orange accent, resolving through three blues.
    case iris

    var stops: [Gradient.Stop] {
        switch self {
        case .neon:
            return GlowBorderStyle.reference.stops
        case .ember:
            // Warm/cool split: gold across most of the lap, easing through a
            // blue band on the top edge (0.68–0.80).
            return [
                .init(color: Color(red: 1.00, green: 0.659, blue: 0.310), location: 0.00), // gold  #FFA84F
                .init(color: Color(red: 0.588, green: 0.749, blue: 1.00), location: 0.68), // blue  #96BFFF
                .init(color: Color(red: 0.588, green: 0.749, blue: 1.00), location: 0.80), // blue  #96BFFF
                .init(color: Color(red: 1.00, green: 0.659, blue: 0.310), location: 1.00), // gold  #FFA84F
            ]
        case .nocturn:
            // Cool blues on the left/bottom, violet across the top, a pink
            // top-right, and a lone gold hotspot at the bottom-right.
            return [
                .init(color: Color(red: 0.87, green: 0.47, blue: 0.75), location: 0.00), // pink (right)
                .init(color: Color(red: 1.00, green: 0.70, blue: 0.36), location: 0.12), // gold (bottom-right)
                .init(color: Color(red: 0.47, green: 0.69, blue: 1.00), location: 0.30), // sky blue (bottom)
                .init(color: Color(red: 0.35, green: 0.55, blue: 1.00), location: 0.42), // bright blue (bottom-left)
                .init(color: Color(red: 0.43, green: 0.51, blue: 1.00), location: 0.55), // indigo (left)
                .init(color: Color(red: 0.59, green: 0.47, blue: 0.98), location: 0.72), // violet (top)
                .init(color: Color(red: 0.84, green: 0.47, blue: 0.84), location: 0.86), // magenta (top-right)
                .init(color: Color(red: 0.87, green: 0.47, blue: 0.75), location: 1.00), // wrap → pink
            ]
        case .iris:
            // Violet anchor with a warm orange accent, resolving through three
            // cool blues back to violet.
            return [
                .init(color: Color(red: 0.588, green: 0.471, blue: 0.980), location: 0.00), // violet      #9678FA
                .init(color: Color(red: 1.00, green: 0.698, blue: 0.361), location: 0.20), // orange      #FFB25C
                .init(color: Color(red: 0.471, green: 0.690, blue: 1.00), location: 0.40), // light blue  #78B0FF
                .init(color: Color(red: 0.349, green: 0.549, blue: 1.00), location: 0.60), // blue        #598CFF
                .init(color: Color(red: 0.431, green: 0.510, blue: 1.00), location: 0.80), // blue-violet #6E82FF
                .init(color: Color(red: 0.588, green: 0.471, blue: 0.980), location: 1.00), // wrap → violet #9678FA
            ]
        }
    }
}

/// How the light is distributed. Each case is a preset block of tuning knobs.
enum GlowStyle {
    /// Soft colored spill onto the component's own surface, minimal outward
    /// spread — the light "fills" the field.
    case inward
    /// A bright halo thrown outward, spilling onto the surroundings.
    case outward
    /// A crisp lit rim only — no inward or outward bloom.
    case edgeOnly

    /// The tuning knobs for this preset (from the design reference).
    fileprivate var knobs: Knobs {
        switch self {
        case .inward:   return Knobs(outwardLeak: 0.7, outwardIntensity: 0.3, inwardLeak: 2.0, inwardIntensity: 1.0, inwardSaturation: 1.3, edgeIntensity: 0.9, edgeWidth: 0.6, ditherAmount: 9.0, backgroundWash: 0.4)
        case .outward:  return Knobs(outwardLeak: 4.0, outwardIntensity: 3.9, inwardLeak: 1.5, inwardIntensity: 0.4, inwardSaturation: 3.0, edgeIntensity: 1.5, edgeWidth: 0.7, ditherAmount: 8.3, backgroundWash: 0.2)
        case .edgeOnly: return Knobs(outwardLeak: 0.0, outwardIntensity: 0.0, inwardLeak: 0.0, inwardIntensity: 0.0, inwardSaturation: 1.0, edgeIntensity: 0.6, edgeWidth: 0.9, ditherAmount: 8.3, backgroundWash: 0.3)
        }
    }

    fileprivate struct Knobs {
        var outwardLeak: Double
        var outwardIntensity: Double
        var inwardLeak: Double
        var inwardIntensity: Double
        var inwardSaturation: Double
        var edgeIntensity: Double
        var edgeWidth: CGFloat
        var ditherAmount: Double
        var backgroundWash: Double
    }
}

extension View {
    /// Overlays the neon glow border on a continuous rounded-rectangle outline.
    ///
    ///     textField.glowBorder(palette: .neon, style: .inward, period: 4.0)
    ///
    /// Pass your own outline via the `shape:` overload when the host isn't a
    /// rounded rectangle (a `Capsule`, say).
    ///
    /// - Parameters:
    ///   - palette: the circulating color theme (default `.neon`).
    ///   - style: how the light is distributed (default `.inward`).
    ///   - period: seconds for one full lap of the colors; `<= 0` freezes them.
    ///   - cornerRadius: the outline's corner radius (default 16).
    ///   - isActive: when `false`, the glow fades out and its timeline pauses so
    ///     there's no idle render cost; toggling it cross-fades the whole effect.
    func glowBorder(
        palette: GlowPalette = .neon,
        style: GlowStyle = .inward,
        period: TimeInterval = 4.0,
        cornerRadius: CGFloat = 16,
        isActive: Bool = true
    ) -> some View {
        let config = GlowBorderStyle.make(palette: palette, style: style, period: period)
        // The renderer insets the outline by `outwardReach`, and insetting a
        // RoundedRectangle shrinks its corner radius by the same amount (a large
        // reach would otherwise square the corners off). Pre-expand the radius so
        // it lands back on `cornerRadius` once inset.
        let outline = RoundedRectangle(
            cornerRadius: cornerRadius + config.outwardReach,
            style: .continuous
        )
        return glowBorder(shape: outline, style: config, isActive: isActive)
    }

    /// Overlays the neon glow border, matching the host's `shape` outline. The
    /// shape is inset by the blur reach, so fixed-radius rounded rectangles lose
    /// their rounding here — prefer the `cornerRadius:` convenience for those;
    /// this overload suits self-scaling outlines like `Capsule`.
    func glowBorder<S: InsettableShape>(
        shape: S,
        palette: GlowPalette = .neon,
        style: GlowStyle = .inward,
        period: TimeInterval = 4.0,
        isActive: Bool = true
    ) -> some View {
        glowBorder(
            shape: shape,
            style: .make(palette: palette, style: style, period: period),
            isActive: isActive
        )
    }
}

extension GlowBorderStyle {
    /// Builds a style from the public presets: `palette` sets the colors,
    /// `style` the distribution knobs, `period` the circulation speed. The
    /// bloom-pass recipe stays at the reference falloff.
    static func make(palette: GlowPalette, style: GlowStyle, period: TimeInterval) -> GlowBorderStyle {
        var config = GlowBorderStyle.reference
        config.stops = palette.stops
        config.period = period
        let knobs = style.knobs
        config.outwardLeak = knobs.outwardLeak
        config.outwardIntensity = knobs.outwardIntensity
        config.inwardLeak = knobs.inwardLeak
        config.inwardIntensity = knobs.inwardIntensity
        config.inwardSaturation = knobs.inwardSaturation
        config.edgeIntensity = knobs.edgeIntensity
        config.edgeWidth = knobs.edgeWidth
        config.ditherAmount = knobs.ditherAmount
        config.backgroundWash = knobs.backgroundWash
        return config
    }
}

// MARK: - Style

/// Every visual knob lives here so looks can be iterated (or A/B'd in the demo
/// screen) without touching the rendering code. Callers normally go through the
/// `.glowBorder(palette:style:period:)` presets; this is the tunable substrate.
struct GlowBorderStyle {

    /// One blurred copy of the border ring. The stack of these — wide/dim to
    /// tight/bright — is the light falloff. Add or remove passes to reshape it.
    struct GlowPass {
        /// Ring thickness before blur (points).
        var lineWidth: CGFloat
        /// Gaussian blur radius at leak == 1. Scaled by the leak amounts.
        var blur: CGFloat
        /// Brightness of this pass. Wide passes should be dim.
        var opacity: Double
    }

    /// Colors around the border and how they spread. Location 0 sits at
    /// 3 o'clock and advances clockwise (0.25 = bottom, 0.5 = left, 0.75 = top).
    /// The *gaps between locations* are the spreading: bunch two stops close
    /// together for a sharp transition, spread them for a slow wash.
    /// Repeat the first color at location 1.0 or the wrap seam will show.
    var stops: [Gradient.Stop]

    /// Seconds for one full lap of the colors around the border.
    /// `<= 0` freezes the circulation (colors still render, just static).
    var period: TimeInterval

    /// Edge-line brightness, 0…2. Below 1 dims the line toward invisible;
    /// 1 is the full saturated color; above 1 the middle of the line burns
    /// toward white (the "overdriven neon tube" look).
    var edgeIntensity: Double

    /// How far light spreads *outside* the shape. 0 = none, 1 = reference
    /// reach, ~2 = heavy spill. Scales the blur radius only — brightness is
    /// `outwardIntensity`.
    var outwardLeak: Double

    /// Color brightness of the outward bloom, 0…2. 1 = reference. Above 1,
    /// extra energy goes into ring thickness (opacity is already saturated).
    var outwardIntensity: Double

    /// How far light spills *inside*, over the component's surface.
    var inwardLeak: Double

    /// Color brightness of the inward spill, 0…2. 1 = reference.
    var inwardIntensity: Double

    /// Saturation boost on the inward spill. Inside a small shape the blur
    /// mixes opposite edges' hues (pink + cyan + …) toward gray; values > 1
    /// pull that mixed light back to vivid color. 1 = off.
    var inwardSaturation: Double

    /// Width of the sharp edge line itself (points).
    var edgeWidth: CGFloat

    /// The bloom recipe, widest/dimmest first.
    var bloomPasses: [GlowPass]

    /// Dither strength for the composited glow, in 8-bit code values. Breaks the
    /// concentric banding the blur stack leaves on a dark surface. 0 = off; ~1 is
    /// the physically-right ±1 LSB, but the presets run a touch higher so the
    /// debanding is unmistakable.
    var ditherAmount: Double = 1.5

    /// Brightness of a big, soft, blurred fill placed *behind* the component, so
    /// the light casts a colored halo on the surrounding surface instead of just
    /// ringing the edge. 0 = off. Uses the same circulating gradient as the rim.
    var backgroundWash: Double = 0.0

    /// Blur radius of the background wash — much wider than any bloom pass, so it
    /// reads as spill on the environment rather than a second rim.
    var washBlur: CGFloat = 60

    /// How far (points) the effect needs to draw beyond the shape's edge so
    /// the outward bloom isn't clipped. The view modifier pads by this.
    var outwardReach: CGFloat {
        let maxBlur = bloomPasses.map(\.blur).max() ?? 0
        let maxLine = bloomPasses.map(\.lineWidth).max() ?? 0
        // ~1.6× blur radius keeps the Gaussian tail from ending in a visible
        // straight clip line on black.
        return maxBlur * CGFloat(max(outwardLeak, 0)) * 1.6 + maxLine / 2 + edgeWidth
    }

    /// Tuned against the reference screenshots: pink at right, orange hotspot
    /// lower-right, blues/cyan on the left, violet across the top. Backs the
    /// `.neon` palette and the base falloff for every preset.
    static let reference = GlowBorderStyle(
        stops: [
            .init(color: Color(red: 1.00, green: 0.25, blue: 0.75), location: 0.00), // pink (right)
            .init(color: Color(red: 1.00, green: 0.55, blue: 0.15), location: 0.08), // orange ramp-in
            .init(color: Color(red: 1.00, green: 0.85, blue: 0.20), location: 0.14), // yellow hotspot
            .init(color: Color(red: 1.00, green: 0.60, blue: 0.25), location: 0.20), // orange ramp-out
            .init(color: Color(red: 0.85, green: 0.30, blue: 0.95), location: 0.30), // violet-pink (bottom)
            .init(color: Color(red: 0.25, green: 0.45, blue: 1.00), location: 0.42), // blue
            .init(color: Color(red: 0.30, green: 0.85, blue: 1.00), location: 0.55), // cyan (left)
            .init(color: Color(red: 0.35, green: 0.40, blue: 1.00), location: 0.70), // blue-violet
            .init(color: Color(red: 0.70, green: 0.30, blue: 1.00), location: 0.85), // purple (top)
            .init(color: Color(red: 1.00, green: 0.25, blue: 0.75), location: 1.00), // wrap → pink
        ],
        period: 8,
        edgeIntensity: 1.4,
        outwardLeak: 1.0,
        outwardIntensity: 1.0,
        inwardLeak: 0.4,
        inwardIntensity: 1.0,
        inwardSaturation: 1.7,
        edgeWidth: 1,
        // Five octaves, blur roughly doubling each step (64 → 4). Real light
        // falloff carries energy at every spatial scale; sampling it at more
        // octaves — with opacity falling off steeply toward the wide end — sums
        // to a smooth inverse-square-ish curve instead of the three visible
        // steps a coarser stack shows. Widest/dimmest first so the hot rim
        // lands on top.
        bloomPasses: [
            .init(lineWidth: 14, blur: 64, opacity: 0.20), // widest, faintest haze
            .init(lineWidth: 11, blur: 32, opacity: 0.32),
            .init(lineWidth: 8,  blur: 16, opacity: 0.48), // mid halo
            .init(lineWidth: 5,  blur: 8,  opacity: 0.66),
            .init(lineWidth: 3,  blur: 4,  opacity: 0.90), // tightest, brightest rim
        ]
    )
}

// MARK: - Glow border view

/// Draws the neon border around any `InsettableShape`. The shape is inset by
/// `style.outwardReach` inside this view's bounds so the bloom has room to
/// draw without being clipped by `drawingGroup` — apply it via
/// `.glowBorder(shape:palette:style:period:)`, which pads the overlay to compensate.
struct GlowBorder<S: InsettableShape>: View {
    var shape: S
    var style: GlowBorderStyle = .reference
    /// When `false`, the rim fades out and the timeline pauses (holding the last
    /// frame) so an unlit field costs nothing per frame.
    var isActive: Bool = true

    var body: some View {
        TimelineView(.animation(paused: !isActive || style.period <= 0)) { context in
            let angle = circulationAngle(at: context.date)
            ZStack {
                if style.outwardLeak > 0 && style.outwardIntensity > 0 {
                    outwardBloom(angle)
                }
                if style.inwardLeak > 0 && style.inwardIntensity > 0 {
                    inwardSpill(angle)
                }
                edgeLine(angle)
            }
            // Flatten the blur stack into one GPU pass. Also the reason the
            // shape is inset: drawingGroup clips at this view's bounds.
            .drawingGroup()
            // De-band the blurred falloff. `amount == 0` is a pass-through, so
            // this can stay unconditional.
            .colorEffect(ShaderLibrary.glowDither(.float(Float(style.ditherAmount))))
        }
        .opacity(isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.35), value: isActive)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Layers

    /// The blurred passes, visible only *outside* the shape.
    private func outwardBloom(_ angle: Angle) -> some View {
        bloomStack(angle, leak: style.outwardLeak, intensity: style.outwardIntensity)
            .mask { outsideMask }
    }

    /// The blurred passes, visible only *inside* the shape. Re-saturated after
    /// the blur so the interior wash stays colorful instead of graying out.
    private func inwardSpill(_ angle: Angle) -> some View {
        bloomStack(angle, leak: style.inwardLeak, intensity: style.inwardIntensity)
            .saturation(style.inwardSaturation)
            .clipShape(borderShape)
    }

    /// The sharp line: colored stroke, plus a thinner white stroke that fades
    /// in as intensity exceeds 1 — white core, colored fringes.
    private func edgeLine(_ angle: Angle) -> some View {
        let colorAmount = min(max(style.edgeIntensity, 0), 1)
        let whiteHot = min(max(style.edgeIntensity - 1, 0), 1)
        return ZStack {
            ring(angle, lineWidth: style.edgeWidth)
                .opacity(colorAmount)
            if whiteHot > 0 {
                borderShape
                    .stroke(.white, lineWidth: style.edgeWidth * 0.55)
                    .blur(radius: 0.5) // melt the white into the color
                    .opacity(whiteHot)
            }
        }
        .blendMode(.plusLighter)
    }

    // MARK: Building blocks

    /// All bloom passes stroked and blurred. `leak` scales spread (blur),
    /// `intensity` scales brightness — above 1, opacity is already saturated,
    /// so the extra energy widens the rings instead.
    private func bloomStack(_ angle: Angle, leak: Double, intensity: Double) -> some View {
        let widthBoost = 1 + max(0, intensity - 1) * 0.6
        return ZStack {
            ForEach(Array(style.bloomPasses.enumerated()), id: \.offset) { _, pass in
                ring(angle, lineWidth: pass.lineWidth * widthBoost)
                    .blur(radius: pass.blur * CGFloat(leak))
                    .opacity(pass.opacity * min(intensity, 1))
                    .blendMode(.plusLighter) // overlapping passes add, like light
            }
        }
    }

    /// The shape, pulled in from this view's bounds so blur can draw around it.
    private var borderShape: S.InsetShape {
        shape.inset(by: style.outwardReach)
    }

    /// One ring: the shape stroked with the circulating conic gradient.
    private func ring(_ angle: Angle, lineWidth: CGFloat) -> some View {
        borderShape.stroke(
            AngularGradient(stops: style.stops, center: .center, angle: angle),
            lineWidth: lineWidth
        )
    }

    /// Alpha mask covering everything *except* the shape's interior.
    private var outsideMask: some View {
        ZStack {
            Rectangle()
            borderShape
                .fill(Color.black)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    /// This border's circulation phase (see `glowCirculationAngle`).
    private func circulationAngle(at date: Date) -> Angle {
        glowCirculationAngle(at: date, period: style.period)
    }
}

/// Rotation phase, wrapped to one lap. Shared by the border and the wash so
/// they circulate in lockstep. The wrap is invisible (360° ≡ 0°) and keeping
/// the angle small matters: feeding the raw clock in (billions of degrees)
/// exceeds Float precision on the GPU — the gradient collapses to a single
/// color and stops moving.
func glowCirculationAngle(at date: Date, period: TimeInterval) -> Angle {
    guard period > 0 else { return .zero }
    let phase = (date.timeIntervalSinceReferenceDate / period)
        .truncatingRemainder(dividingBy: 1)
    return .degrees(phase * 360)
}

// MARK: - Background wash

/// A big, dim, heavily-blurred fill of the shape drawn *behind* the component,
/// so the light casts a soft colored halo on the surrounding surface — the cue
/// that an object is illuminating its environment, not just wearing a lit rim.
/// Shares the border's circulating gradient so the two stay in sync.
struct GlowWash<S: InsettableShape>: View {
    var shape: S
    var style: GlowBorderStyle = .reference
    /// Mirrors `GlowBorder.isActive`: fades the halo out and pauses its timeline
    /// when off, so the wash and rim light up and die together.
    var isActive: Bool = true

    var body: some View {
        if style.backgroundWash > 0 {
            TimelineView(.animation(paused: !isActive || style.period <= 0)) { context in
                let angle = glowCirculationAngle(at: context.date, period: style.period)
                shape
                    .fill(AngularGradient(stops: style.stops, center: .center, angle: angle))
                    .blur(radius: style.washBlur)
                    // 0.5 keeps a full-strength wash (slider at 1) from washing
                    // the surroundings to white; the slider scales from there.
                    .opacity(0.5 * min(style.backgroundWash, 2))
                    .blendMode(.plusLighter)
            }
            .opacity(isActive ? 1 : 0)
            .animation(.easeInOut(duration: 0.35), value: isActive)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Low-level modifier

extension View {
    /// Overlays the neon border for a fully-specified `style`, padded outward so
    /// the bloom isn't clipped. `shape` must match the host component's outline.
    /// The preset `.glowBorder(palette:style:period:)` API is preferred; this is
    /// the escape hatch (and what the DEBUG playground drives).
    func glowBorder<S: InsettableShape>(
        shape: S,
        style: GlowBorderStyle,
        isActive: Bool = true
    ) -> some View {
        // Wash sits *behind* the component (colored spill on the surroundings);
        // the neon rim sits in front. Both are padded out so their blur isn't
        // clipped by the host's bounds. `isActive` fades both and pauses their
        // timelines when off (handled inside each view).
        background {
            GlowWash(shape: shape, style: style, isActive: isActive)
                .padding(-style.washBlur)
        }
        .overlay {
            GlowBorder(shape: shape, style: style, isActive: isActive)
                .padding(-style.outwardReach)
        }
    }
}

// MARK: - Previews

#if DEBUG
/// A stand-in creation field carrying the glow, on black — one per `GlowStyle`.
private struct GlowBorderShowcase: View {
    var style: GlowStyle

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
            Text("What do you want to track?")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.primary.opacity(0.05))
        )
        .glowBorder(style: style)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview("Inward") { GlowBorderShowcase(style: .inward) }

#Preview("Outward") { GlowBorderShowcase(style: .outward) }

#Preview("Edge only") { GlowBorderShowcase(style: .edgeOnly) }
#endif
