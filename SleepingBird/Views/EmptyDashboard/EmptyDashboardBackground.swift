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
        if colorScheme == .dark {
            return [
                blend(Color(red: 0.18, green: 0.14, blue: 0.32)),  // top-left: deep indigo
                blend(Color(red: 0.10, green: 0.10, blue: 0.18)),  // top-center: near black
                blend(Color(red: 0.10, green: 0.28, blue: 0.30)),  // top-right: deep teal
                blend(Color(red: 0.20, green: 0.16, blue: 0.34)),  // mid-left: dark lavender
                blend(Color(red: 0.07, green: 0.07, blue: 0.12)),  // center: near-black dominant
                blend(Color(red: 0.32, green: 0.18, blue: 0.14)),  // mid-right: dark amber
                blend(Color(red: 0.10, green: 0.30, blue: 0.32)),  // bottom-left: dark turquoise
                blend(Color(red: 0.30, green: 0.16, blue: 0.12)),  // bottom-center: dark peach
                blend(Color(red: 0.40, green: 0.18, blue: 0.14)),  // bottom-right: deep salmon
            ]
        }
        return [
            blend(Color(red: 0.91, green: 0.88, blue: 0.98)),  // top-left: lavender
            blend(Color(red: 0.97, green: 0.97, blue: 1.00)),  // top-center: near white
            blend(Color(red: 0.85, green: 0.97, blue: 0.96)),  // top-right: cyan-green
            blend(Color(red: 0.93, green: 0.91, blue: 0.99)),  // mid-left: soft lavender
            blend(Color(red: 0.99, green: 0.98, blue: 1.00)),  // center: near white dominant
            blend(Color(red: 1.00, green: 0.94, blue: 0.91)),  // mid-right: light peach
            blend(Color(red: 0.87, green: 0.97, blue: 0.97)),  // bottom-left: cyan/turquoise
            blend(Color(red: 1.00, green: 0.93, blue: 0.90)),  // bottom-center: light peach
            blend(Color(red: 1.00, green: 0.86, blue: 0.80)),  // bottom-right: peach/salmon
        ]
    }

    private func blend(_ color: Color) -> Color {
        let t = max(0, min(1, colorIntensity))
        let neutral: Color = colorScheme == .dark ? .black : .white
        return color.mix(with: neutral, by: 1 - t)
    }
}

#Preview {
    EmptyDashboardBackground()
}
