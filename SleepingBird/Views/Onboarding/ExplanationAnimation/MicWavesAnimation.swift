//
//  MicWavesAnimation.swift
//  SleepingBird
//
//  Created by Olivier Picard on 01/06/2026.
//

import SwiftUI

struct MicWavesAnimation: View {
    var color: Color = .primary

    @State private var animating = false

    var body: some View {
        ZStack {
            // Animated filled discs expanding from center
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(color.opacity(animating ? 0 : 0.4))
                    .frame(width: 50, height: 50)
                    .scaleEffect(animating ? 5 : 1.0)
                    .animation(
                        .easeOut(duration: 2.2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.72),
                        value: animating
                    )
            }

            // Center disc with mic
            Circle()
                .fill(color)
                .frame(width: 72, height: 72)

            Image(systemName: "mic.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .accessibilityHidden(true)
        }
        .frame(width: 320, height: 320)
        .onAppear { animating = true }
    }
}

#Preview {
    VStack(spacing: 0) {
        MicWavesAnimation(color: .green)
        MicWavesAnimation(color: .indigo)
        MicWavesAnimation(color: .gray)
    }
    .padding()
}
