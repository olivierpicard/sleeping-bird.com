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

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingFlow(onComplete: {
                    hasCompletedOnboarding = true
                    PostHogSDK.shared.capture("onboarding_completed")
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.5), value: hasCompletedOnboarding)
    }
}

#Preview("Onboarding") {
    RootView()
        .environment(MetricGenerator())
        .environment(Store())
        .modelContainer(for: Metric.self, inMemory: true)
}
