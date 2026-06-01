//
//  RootView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 31/05/2026.
//

import SwiftData
import SwiftUI

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
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasCompletedOnboarding = true
                    }
                })
                .transition(.opacity)
            }
        }
    }
}

#Preview("Onboarding") {
    RootView()
        .environment(MetricGenerator())
        .modelContainer(for: Metric.self, inMemory: true)
}

