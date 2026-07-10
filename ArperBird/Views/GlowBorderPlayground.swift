//
//  GlowBorderPlayground.swift
//  ArperBird
//
//  DEBUG-only tuning playground for the neon `.glowBorder` (see
//  `GlowBorder.swift`). Every knob of `GlowBorderStyle` gets a slider, plus a
//  palette editor, so looks can be iterated by hand and the resulting values
//  read off for a new `GlowShape`/`GlowPalette` preset.
//

#if DEBUG
import SwiftUI
import UIKit

// MARK: - Demo screen

/// Interactive playground: every knob on a slider, plus palettes that
/// demonstrate the color/spreading control.
struct GlowBorderPlayground: View {
    @State private var outwardLeak = 1.5
    @State private var outwardIntensity = 1.1
    @State private var inwardLeak = 1.0
    @State private var inwardIntensity = 0.4
    @State private var inwardSaturation = 1.7
    @State private var edgeIntensity = 0.7
    @State private var edgeWidth = 1.0
    @State private var period = 8.0
    @State private var ditherAmount = 1.5
    @State private var backgroundWash = 0.35
    @State private var palette: Palette = .reference
    @State private var stops: [EditableStop] = GlowBorderStyle.reference.stops.map {
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
        /// showing that spreading is controlled purely by stop locations. The
        /// production palettes reuse `GlowPalette`'s canonical stops.
        var stops: [Gradient.Stop] {
            switch self {
            case .reference:
                return GlowBorderStyle.reference.stops
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
                return GlowPalette.nocturn.stops
            case .ember:
                return GlowPalette.ember.stops
            case .iris:
                return GlowPalette.iris.stops
            }
        }
    }

    private var style: GlowBorderStyle {
        var style = GlowBorderStyle.reference
        style.stops = editedStops
        style.period = period
        style.edgeIntensity = edgeIntensity
        style.outwardLeak = outwardLeak
        style.outwardIntensity = outwardIntensity
        style.inwardLeak = inwardLeak
        style.inwardIntensity = inwardIntensity
        style.inwardSaturation = inwardSaturation
        style.edgeWidth = CGFloat(edgeWidth)
        style.ditherAmount = ditherAmount
        style.backgroundWash = backgroundWash
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
                .glowBorder(shape: Capsule(), style: style)
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
        ScrollView {
            controlStack
                .padding(20)
        }
        // Cap the panel so the growing list of knobs scrolls inside its card
        // instead of shoving the preview component off-screen.
        .frame(maxHeight: 380)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(16)
    }

    private var controlStack: some View {
        VStack(spacing: 14) {
            Picker("Palette", selection: $palette) {
                ForEach(Palette.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            colorSection

            Divider().overlay(.primary.opacity(0.1))

            sliderRow("Out spread", value: $outwardLeak, in: 0...4)
            sliderRow("Out intensity", value: $outwardIntensity, in: 0...4)
            sliderRow("In spread", value: $inwardLeak, in: 0...4)
            sliderRow("In intensity", value: $inwardIntensity, in: 0...2)
            sliderRow("In saturation", value: $inwardSaturation, in: 1...3)
            sliderRow("Edge intensity", value: $edgeIntensity, in: 0...2)
            sliderRow("Edge width", value: $edgeWidth, in: 0...6)
            sliderRow("Dither", value: $ditherAmount, in: 0...16)
            sliderRow("Bg wash", value: $backgroundWash, in: 0...2)
            sliderRow("Period (s/lap)", value: $period, in: 1...20)
        }
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
    let stops: [GlowBorderPlayground.EditableStop]
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

    private func row(for stop: GlowBorderPlayground.EditableStop) -> some View {
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
    GlowBorderPlayground()
}
#endif
