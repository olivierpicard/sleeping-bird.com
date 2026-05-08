//
//  EmptyDashboardBackground.swift
//  SleepingBird
//
//  Created by Olivier Picard on 08/05/2026.
//

import SwiftUI

struct EmptyDashboardBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var colorIntensity: Double = 1.0

    var body: some View {

        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: colorfulColors
        )
        .ignoresSafeArea()
    }

    private var colorfulColors: [Color] {
        // Base hues (0...1) and a "weight" indicating how dominant the stop is.
        // Lower weight = closer to neutral (near-white in light, near-black in dark).
        let stops: [(hue: Double, weight: Double)] = [
            (0.72, 0.6),  // top-left: indigo/lavender
            (0.70, 0.1),  // top-center: near neutral
            (0.48, 0.6),  // top-right: teal/cyan
            (0.74, 0.5),  // mid-left: soft lavender
            (0.70, 0.0),  // center: neutral dominant
            (0.06, 0.6),  // mid-right: amber/peach
            (0.50, 0.7),  // bottom-left: turquoise
            (0.05, 0.7),  // bottom-center: peach
            (0.03, 0.9),  // bottom-right: salmon
        ]
        return stops.map { tone(hue: $0.hue, weight: $0.weight) }
    }

    private func tone(hue: Double, weight: Double) -> Color {
        let t = max(0, min(1, colorIntensity)) * weight
        let saturation: Double
        let brightness: Double
        if colorScheme == .dark {
            // Dark mode: low brightness, moderate saturation, fading to near-black.
            saturation = 0.85 * t + 0.15
            brightness = 0.12 + 0.3 * t
        } else {
            // Light mode: high brightness, low saturation, fading to near-white.
            saturation = 0.18 * t + 0.02
            brightness = 1.00 - 0.05 * t
        }
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

#Preview {
    EmptyDashboardBackground()
}
