//
//  AiGlowBorderMockup2.swift
//  ArperBird
//
//  UI-testing mockup of a neon "emits light" border (reference: neon capsule
//  frames on black — thin white-hot filament, colored edge, big soft bloom,
//  hues circulating around the shape).
//
//  How it works, bottom to top:
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
//  Mockup only — no production wiring. Layers are data (`bloomPasses`) and
//  independently gated, so features are easy to add, retune, or delete.
//

import SwiftUI
import UIKit

// MARK: - Style

/// Every visual knob lives here so looks can be iterated (or A/B'd in the demo
/// screen) without touching the rendering code.
struct AiGlowBorderMockup2Style {

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
    /// lower-right, blues/cyan on the left, violet across the top.
    static let reference = AiGlowBorderMockup2Style(
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
        edgeWidth: 2.5,
        bloomPasses: [
            .init(lineWidth: 14, blur: 42, opacity: 0.45), // far, dim spill
            .init(lineWidth: 8,  blur: 16, opacity: 0.65), // mid halo
            .init(lineWidth: 4,  blur: 5,  opacity: 0.90), // tight, saturated rim
        ]
    )
}

// MARK: - Glow border view

/// Draws the neon border around any `InsettableShape`. The shape is inset by
/// `style.outwardReach` inside this view's bounds so the bloom has room to
/// draw without being clipped by `drawingGroup` — apply it via
/// `.aiGlowBorderMockup2(shape:style:)`, which pads the overlay to compensate.
struct AiGlowBorderMockup2<S: InsettableShape>: View {
    var shape: S
    var style: AiGlowBorderMockup2Style = .reference

    var body: some View {
        TimelineView(.animation(paused: style.period <= 0)) { context in
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
        }
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

    /// Rotation phase, wrapped to one lap. The wrap is invisible (a conic
    /// gradient at 360° == 0°) and keeping the angle small matters: feeding the
    /// raw clock in (billions of degrees) exceeds Float precision on the GPU —
    /// the gradient collapses to a single color and stops moving.
    private func circulationAngle(at date: Date) -> Angle {
        guard style.period > 0 else { return .zero }
        let phase = (date.timeIntervalSinceReferenceDate / style.period)
            .truncatingRemainder(dividingBy: 1)
        return .degrees(phase * 360)
    }
}

// MARK: - Convenience modifier

extension View {
    /// Overlays the neon border, padded outward so the bloom isn't clipped.
    /// `shape` must match the host component's outline.
    func aiGlowBorderMockup2<S: InsettableShape>(
        shape: S,
        style: AiGlowBorderMockup2Style = .reference
    ) -> some View {
        overlay {
            AiGlowBorderMockup2(shape: shape, style: style)
                .padding(-style.outwardReach)
        }
    }
}

// MARK: - Demo screen

/// Interactive playground: every requested knob on a slider, plus palettes
/// that demonstrate the color/spreading control.
struct AiGlowBorderMockup2Screen: View {
    @State private var outwardLeak = 1.5
    @State private var outwardIntensity = 1.1
    @State private var inwardLeak = 1.0
    @State private var inwardIntensity = 0.4
    @State private var edgeIntensity = 0.7
    @State private var period = 8.0
    @State private var palette: Palette = .reference
    @State private var stops: [EditableStop] = AiGlowBorderMockup2Style.reference.stops.map {
        EditableStop(color: $0.color, location: Double($0.location))
    }
    @State private var selectedStopID: EditableStop.ID?
    @State private var showingValues = false

    /// One editable gradient stop in the color section. `location` is a `Double`
    /// here so it binds to a slider; it's converted back to `Gradient.Stop`
    /// (CGFloat) when the style is built.
    struct EditableStop: Identifiable {
        let id = UUID()
        var color: Color
        var location: Double
    }

    enum Palette: String, CaseIterable, Identifiable {
        case reference = "Reference"
        case aurora = "Aurora"
        case bunched = "Bunched"
        case nocturne = "Nocturne"
        case ember = "Ember"
        case iris = "Iris"
        var id: String { rawValue }

        /// `bunched` uses the reference hues but crowds the locations together,
        /// showing that spreading is controlled purely by stop locations.
        var stops: [Gradient.Stop] {
            switch self {
            case .reference:
                return AiGlowBorderMockup2Style.reference.stops
            case .aurora:
                return [
                    .init(color: Color(red: 0.20, green: 0.95, blue: 0.70), location: 0.00),
                    .init(color: Color(red: 0.15, green: 0.60, blue: 1.00), location: 0.35),
                    .init(color: Color(red: 0.55, green: 0.35, blue: 1.00), location: 0.65),
                    .init(color: Color(red: 0.20, green: 0.95, blue: 0.70), location: 1.00),
                ]
            case .bunched:
                return [
                    .init(color: Color(red: 1.00, green: 0.25, blue: 0.75), location: 0.00),
                    .init(color: Color(red: 1.00, green: 0.45, blue: 0.20), location: 0.05),
                    .init(color: Color(red: 0.25, green: 0.45, blue: 1.00), location: 0.12),
                    .init(color: Color(red: 0.30, green: 0.85, blue: 1.00), location: 0.60),
                    .init(color: Color(red: 0.70, green: 0.30, blue: 1.00), location: 0.90),
                    .init(color: Color(red: 1.00, green: 0.25, blue: 0.75), location: 1.00),
                ]
            case .nocturne:
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
            case .ember:
                // Warm/cool split: gold across most of the lap, easing through a
                // blue band on the top edge (0.68–0.80).
                return [
                    .init(color: Color(red: 1.00, green: 0.659, blue: 0.310), location: 0.00), // gold  #FFA84F
                    .init(color: Color(red: 0.588, green: 0.749, blue: 1.00), location: 0.68), // blue  #96BFFF
                    .init(color: Color(red: 0.588, green: 0.749, blue: 1.00), location: 0.80), // blue  #96BFFF
                    .init(color: Color(red: 1.00, green: 0.659, blue: 0.310), location: 1.00), // gold  #FFA84F
                ]
            case .iris:
                // Violet anchor with a warm orange accent, resolving through
                // three cool blues back to violet.
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

    private var style: AiGlowBorderMockup2Style {
        var style = AiGlowBorderMockup2Style.reference
        style.stops = editedStops
        style.period = period
        style.edgeIntensity = edgeIntensity
        style.outwardLeak = outwardLeak
        style.outwardIntensity = outwardIntensity
        style.inwardLeak = inwardLeak
        style.inwardIntensity = inwardIntensity
        return style
    }

    var body: some View {
        ZStack {
            // Follows the system appearance so the effect can be seen in light
            // mode too (the additive glow reads best on the dark variant).
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // The glowing component — a stand-in creation field.
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                    Text("What do you want to track?")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 26)
                .background(Capsule().fill(.primary.opacity(0.05)))
                .aiGlowBorderMockup2(shape: Capsule(), style: style)
                .padding(.horizontal, 40)

                Spacer()

                controls
            }
        }
        .onAppear {
            if selectedStopID == nil { selectedStopID = sortedStops.first?.id }
        }
        .onChange(of: palette) { _, newValue in loadPalette(newValue) }
    }

    // MARK: Color editing

    /// The editable stops, sorted by location, as `Gradient.Stop`s for the style.
    private var editedStops: [Gradient.Stop] {
        sortedStops.map { Gradient.Stop(color: $0.color, location: CGFloat($0.location)) }
    }

    /// Editable stops in draw order (left → right around the lap).
    private var sortedStops: [EditableStop] {
        stops.sorted { $0.location < $1.location }
    }

    /// Index of the selected stop in the *unsorted* backing array, so bindings
    /// like `$stops[idx].color` point at the right element.
    private var selectedIndex: Int? {
        guard let id = selectedStopID else { return nil }
        return stops.firstIndex { $0.id == id }
    }

    /// Replace the editable stops with a preset's, selecting the first.
    private func loadPalette(_ palette: Palette) {
        stops = palette.stops.map { EditableStop(color: $0.color, location: Double($0.location)) }
        selectedStopID = sortedStops.first?.id
    }

    /// Add a stop in the middle of the widest gap, so it lands somewhere it can
    /// actually be seen, and select it for immediate editing.
    private func addColor() {
        let ordered = sortedStops
        var newLocation = 0.5
        var widestGap = -1.0
        for index in ordered.indices {
            let start = ordered[index].location
            let end = index + 1 < ordered.count ? ordered[index + 1].location : 1.0
            let gap = end - start
            if gap > widestGap {
                widestGap = gap
                newLocation = (start + end) / 2
            }
        }
        let stop = EditableStop(color: .white, location: newLocation)
        stops.append(stop)
        selectedStopID = stop.id
    }

    /// Space every stop evenly across the lap (0…1), keeping their current
    /// color order.
    private func distributeEvenly() {
        let ordered = sortedStops
        guard ordered.count > 1 else { return }
        let step = 1.0 / Double(ordered.count - 1)
        for (offset, stop) in ordered.enumerated() {
            guard let index = stops.firstIndex(where: { $0.id == stop.id }) else { continue }
            stops[index].location = Double(offset) * step
        }
    }

    /// Remove the selected stop (a gradient needs at least two), selecting a
    /// neighbor.
    private func deleteSelectedColor() {
        guard stops.count > 2, let id = selectedStopID else { return }
        stops.removeAll { $0.id == id }
        selectedStopID = sortedStops.first?.id
    }

    private var controls: some View {
        VStack(spacing: 14) {
            Picker("Palette", selection: $palette) {
                ForEach(Palette.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            colorSection

            Divider().overlay(.primary.opacity(0.1))

            sliderRow("Out spread", value: $outwardLeak, in: 0...2)
            sliderRow("Out intensity", value: $outwardIntensity, in: 0...2)
            sliderRow("In spread", value: $inwardLeak, in: 0...2)
            sliderRow("In intensity", value: $inwardIntensity, in: 0...2)
            sliderRow("Edge intensity", value: $edgeIntensity, in: 0...2)
            sliderRow("Period (s/lap)", value: $period, in: 1...20)
        }
        .padding(20)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(16)
    }

    /// Swatch strip + inline editor for the gradient's colors: tap a swatch to
    /// select it, then recolor / reposition / delete it, or add a new one.
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Colors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingValues = true
                } label: {
                    Label("Show values", systemImage: "list.number")
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.primary)
                Button {
                    distributeEvenly()
                } label: {
                    Label("Distribute evenly", systemImage: "arrow.left.and.right")
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.primary)
                .disabled(stops.count < 2)
                Button {
                    addColor()
                } label: {
                    Label("Add color", systemImage: "plus.circle.fill")
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(sortedStops) { stop in
                        Circle()
                            .fill(stop.color)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 1))
                            .overlay(
                                Circle().strokeBorder(
                                    .primary, lineWidth: selectedStopID == stop.id ? 2.5 : 0
                                )
                            )
                            .onTapGesture { selectedStopID = stop.id }
                    }
                }
                .padding(.vertical, 2)
            }

            if let index = selectedIndex {
                HStack(spacing: 12) {
                    ColorPicker("Selected color", selection: $stops[index].color, supportsOpacity: false)
                        .labelsHidden()

                    VStack(spacing: 2) {
                        Slider(value: $stops[index].location, in: 0...1)
                        Text("Position \(stops[index].location, format: .number.precision(.fractionLength(2)))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        deleteSelectedColor()
                    } label: {
                        Label("Delete color", systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.primary)
                    .disabled(stops.count <= 2)
                }
            }
        }
        .sheet(isPresented: $showingValues) {
            PaletteValuesView(stops: sortedStops)
        }
    }

    private func sliderRow(
        _ title: String, value: Binding<Double>, in range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Slider(value: value, in: range)
            Text(value.wrappedValue.formatted(.number.precision(.fractionLength(1))))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Palette values panel

/// Read-only inspector listing each stop's position, RGB, and hex, plus a
/// one-tap copy of the whole palette as text — handy for pasting into an AI
/// prompt when iterating on a palette.
private struct PaletteValuesView: View {
    let stops: [AiGlowBorderMockup2Screen.EditableStop]
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(stops) { stop in
                        row(for: stop)
                    }

                    Button {
                        UIPasteboard.general.string = exportText
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy all as text",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Palette values")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(for stop: AiGlowBorderMockup2Screen.EditableStop) -> some View {
        let (r, g, b) = rgb(of: stop.color)
        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(stop.color)
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.2))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("Position \(stop.location, format: .number.precision(.fractionLength(2)))")
                    .font(.subheadline.monospacedDigit())
                Text("RGB(\(r), \(g), \(b))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(hex(r, g, b))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    /// The palette as one text block, ordered by position.
    private var exportText: String {
        stops.map { stop in
            let (r, g, b) = rgb(of: stop.color)
            let position = String(format: "%.2f", stop.location)
            return "Position \(position) — RGB(\(r), \(g), \(b)) — \(hex(r, g, b))"
        }
        .joined(separator: "\n")
    }

    /// 0–255 channels for a SwiftUI `Color`, via `UIColor`.
    private func rgb(of color: Color) -> (Int, Int, Int) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    private func hex(_ r: Int, _ g: Int, _ b: Int) -> String {
        String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Previews

#Preview("Playground") {
    AiGlowBorderMockup2Screen()
}

/// Big empty frame on black, matching the reference screenshots.
#Preview("Full frame") {
    AiGlowBorderMockup2(shape: Capsule())
        .frame(height: 300)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
}
