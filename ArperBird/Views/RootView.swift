//
//  RootView.swift
//  ArperBird
//
//  Created by Olivier Picard on 31/05/2026.
//

import SwiftData
import PostHog
import SwiftUI
import TipKit

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
//    @State private var hasCompletedOnboarding = false

    /// True only when onboarding finished *this session* — lets the empty
    /// dashboard play its entrance stagger on the hand-off from `StartView`,
    /// without replaying it on a regular cold launch.
    @State private var cameFromOnboarding = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                ContentView(animatesEmptyDashboardEntrance: cameFromOnboarding)
                    .transition(.opacity)
            } else {
                OnboardingFlow(onComplete: {
                    cameFromOnboarding = true
                    hasCompletedOnboarding = true
                    PostHogSDK.shared.capture("onboarding_completed")
                })
                .transition(.opacity)
            }
        }
        // Kept short: `StartView` plays its exit choreography *before* calling
        // `onComplete`, so this fade only has to cover the actual view swap —
        // the two screens share the same static mesh background, which just
        // "blooms" from intensity 0.6 to 1.0 underneath it.
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
    }
}

#Preview("Onboarding") {
    RootView()
        .environment(MetricGenerator())
        .environment(Store())
        .modelContainer(for: Metric.self, inMemory: true)
}

