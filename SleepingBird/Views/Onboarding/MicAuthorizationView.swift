//
//  MicAuthorizationView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 31/05/2026.
//

import AVFoundation
import PostHog
import SwiftUI
import UIKit

struct MicAuthorizationView: View {
    var onComplete: () -> Void = {}

    /// Multiplier applied to the hero's surrounding rings, fill, and badge.
    /// The central mic icon keeps its actual size regardless of this value.
    /// `1` is the original size; values below shrink it proportionally.
    var heroScale: CGFloat = 0.8

    @Environment(\.colorScheme) private var colorScheme

    private let accent = Color.indigo

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
//            progressBar
//                .padding(.top, 8)

            micHero
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

            Spacer(minLength: 0)
            titleBlock
                .padding(.bottom, 80)

//            Spacer(minLength: 80)
            continueButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            EmptyDashboardBackground(intensity: 0.3)
                .ignoresSafeArea()
        }
        .trackScreen("Onboarding_Microphone")
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < 3 ? accent : Color(uiColor: .systemGray5))
                    .frame(height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step 3 of 4")
    }

    //  MARK: - Hero

    private var isDark: Bool { colorScheme == .dark }

    private var micHero: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    accent.opacity(isDark ? 0.30 : 0.12),
                    lineWidth: isDark ? 1.5 : 1
                )
                .frame(width: 300 * heroScale, height: 300 * heroScale)
            Circle()
                .strokeBorder(
                    accent.opacity(isDark ? 0.45 : 0.18),
                    lineWidth: isDark ? 1.5 : 1
                )
                .frame(width: 220 * heroScale, height: 220 * heroScale)
            Circle()
                .fill(accent.opacity(isDark ? 0.28 : 0.12))
                .frame(width: 132 * heroScale, height: 132 * heroScale)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 25 * heroScale, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40 * heroScale, height: 40 * heroScale)
                        .background(Circle().fill(accent))
                        .background(
                            Circle()
                                .fill(Color(uiColor: .systemBackground))
                                .padding(-3 * heroScale)
                        )
                        .offset(x: 6 * heroScale, y: 6 * heroScale)
                }
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(accent)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(
                "It all starts with your \(Text("mic").foregroundStyle(accent))"
            )
            .font(.system(size: 36, weight: .heavy))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                "Create trackers just by dictating your intentions — your voice is never stored or shared."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button(action: { requestMicrophoneAccess() }) {
            // Distinct key: the shared "Continue" key is mapped to "Subscribe" by the paywall.
            Text("Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
        }
        .controlSize(.extraLarge)
        .buttonStyle(.glassProminent)
        .tint(accent)
    }

    // MARK: - Permission

    private func requestMicrophoneAccess() {
        // In SwiftUI Previews the system permission prompt can't be presented,
        // so the request never resumes — advance without it.
        guard !isRunningInPreview else {
            onComplete()
            return
        }
        Task { @MainActor in
            let granted = await AVAudioApplication.requestRecordPermission()
            PostHogSDK.shared.capture(
                "mic_permission_responded",
                properties: ["granted": granted]
            )
            onComplete()
        }
    }

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#Preview {
    MicAuthorizationView()
}
