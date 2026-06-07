//
//  MicWavesAnimation.swift
//  SleepingBird
//
//  Created by Olivier Picard on 01/06/2026.
//

import SwiftUI

struct MicWavesAnimation: View {
    var color: Color = .primary
    var isActive: Bool = true

    @State private var waveActive: [Bool] = Array(repeating: false, count: 4)
    @State private var waveTasks: [Task<Void, Never>] = []

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color.opacity(waveActive[i] ? 0 : 0.4))
                    .frame(width: 50, height: 50)
                    .scaleEffect(waveActive[i] ? 10 : 1.0)
                    .animation(.easeOut(duration: 3.2), value: waveActive[i])
            }

            Circle()
                .fill(color)
                .frame(width: 72, height: 72)

            Image(systemName: "mic.fill")
                .font(.system(size: 28))
                .foregroundStyle(.background)
                .accessibilityHidden(true)
        }
        .frame(width: 320, height: 320)
        .onAppear { if isActive { startLoop() } }
        .onDisappear { stopLoop() }
        .onChange(of: isActive) { _, active in
            active ? startLoop() : stopLoop()
        }
    }

    private func startLoop() {
        stopLoop()
        // Instant reset so restarted waves begin from scale 1
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { for i in 0..<4 { waveActive[i] = false } }

        waveTasks = (0..<4).map { i in
            Task { @MainActor in
                if i > 0 {
                    do { try await Task.sleep(for: .seconds(Double(i) * 0.72)) } catch { return }
                }
                while !Task.isCancelled {
                    waveActive[i] = true
                    do { try await Task.sleep(for: .seconds(3.2)) } catch { break }
                    // Instant reset to scale 1 so the next wave emits seamlessly
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) { waveActive[i] = false }
                }
            }
        }
    }

    // Cancels tasks — in-progress wave animations complete on their own
    // since waveActive[i] remains true until the animation finishes naturally.
    private func stopLoop() {
        waveTasks.forEach { $0.cancel() }
        waveTasks = []
    }
}

#Preview {
    @Previewable @State var active = true
    VStack(spacing: 0) {
        MicWavesAnimation(color: .green, isActive: active)
        Toggle("Active", isOn: $active).padding()
    }
    .padding()
}
