//
//  MiniChart.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/04/2026.
//

import Foundation
import SwiftUI

protocol MiniChart: View {
    /// Whether the card should inset this chart from its horizontal edges.
    /// Edge-to-edge charts (line, no-data) return false to run flush.
    var usesCardInset: Bool { get }
}

extension MiniChart {
    var usesCardInset: Bool { true }   // safe default: padded
}

// MARK: - Reveal animation

/// Shared timing + math for the tracker-creation "done" reveal, where the chart
/// performs on entry — bars/line rise as a travelling wave, calendar cells scale
/// in one by one. Charts opt in via an `animate` flag (default off, so the
/// dashboard is untouched) and drive a single `progress: 0→1` state; this helper
/// turns that scalar into a per-element local progress so a wave sweeps across
/// the elements from a single animatable value (no per-element state).
enum ChartReveal {
    /// Beat after the card's spring settles before the data starts moving, so
    /// the card lands *then* comes alive.
    static let startDelay: Double = 0.3
    /// How long the wave takes to sweep the whole chart.
    static let duration: Double = 1.2
    /// How many elements are mid-rise at once — a larger ramp is a softer, more
    /// overlapping wave; a smaller one is a crisper one-by-one.
    static let ramp: CGFloat = 2.5

    /// The height each bar *starts* at, as a fraction of its final value, before
    /// its beat of the wave settles it the rest of the way up. Near 1 so bars
    /// fade in and nudge into place (an Apple-style settle) rather than pumping
    /// the full height up from zero. 1 would be a pure fade with no motion.
    static let riseFloor: CGFloat = 0.85

    /// The linear sweep used to drive `progress`; the per-element easing lives in
    /// `local(_:index:count:)` via `smoothstep`, so each element eases in on its
    /// own while the wave front travels at a constant rate.
    static var animation: Animation { .linear(duration: duration).delay(startDelay) }

    /// How long the slower calendar sweep takes. The calendar charts have only a
    /// handful of large cells, so a more deliberate wave reads better on them than
    /// the brisk many-bar sweep.
    static let calendarDuration: Double = 1.6

    /// A slower sweep for the calendar reveals (date + binary), whose few big
    /// cells deserve a more deliberate wave than the dense bar/line charts.
    static var calendarAnimation: Animation {
        .linear(duration: calendarDuration).delay(startDelay)
    }

    /// A gentler curve for single, unstaggered fills (the goal gauge, a
    /// single-point line) that just ease to their mark.
    static var fillAnimation: Animation { .easeOut(duration: 0.6).delay(startDelay) }

    /// Local `0...1` for element `index` of `count`, given the global `progress`,
    /// as a travelling wave from leading (index 0) to trailing. Each element
    /// stays at 0 until the wave front reaches it, then eases to 1.
    static func local(_ progress: CGFloat, index: Int, count: Int) -> CGFloat {
        guard count > 0 else { return progress }
        let head = progress * (CGFloat(count) + ramp)
        let t = (head - CGFloat(index)) / ramp
        return smoothstep(min(max(t, 0), 1))
    }

    /// Classic smoothstep — an S-curve so each element accelerates and settles
    /// rather than moving linearly.
    static func smoothstep(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }
}

/// Drives a chart's marks from a `0→1` scalar that SwiftUI interpolates
/// *frame by frame*, so a single animatable value can sweep a leading→trailing
/// wave across the marks.
///
/// Why this exists: SwiftUI only interpolates values exposed through
/// `animatableData`. A plain `@State` scalar read in arithmetic (e.g.
/// `value * progress`) is **not** interpolated — `withAnimation` jumps it
/// straight to its target, so `ChartReveal.local` would only ever see 0 then 1
/// and every bar would rise at once (Swift Charts tweening them uniformly). By
/// making `progress` the `animatableData` of this view, SwiftUI steps it across
/// every frame and rebuilds `content` with each in-between value — the built-in
/// Apple mechanism for animating an arbitrary scalar (the same one used for
/// number counters and custom `Shape`s).
///
/// The rebuilt content already carries the exact heights for that instant, so we
/// clear the child transaction's animation — otherwise Charts would add its own
/// tween on top of each frame and smear the wave back into a uniform rise.
struct ChartWaveReveal<Content: View>: View, Animatable {
    var progress: CGFloat
    private let content: (CGFloat) -> Content

    init(progress: CGFloat, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.progress = progress
        self.content = content
    }

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        content(progress)
            .transaction { $0.animation = nil }
    }
}
