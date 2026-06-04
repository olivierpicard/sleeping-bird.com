//
//  RootView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 31/05/2026.
//

import SwiftData
import PostHog
import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
//    @State private var hasCompletedOnboarding = false

    @Environment(Store.self) private var store
    @Query private var metrics: [Metric]

    /// The free allowance is one generated metric. Once the user has used it
    /// and is not premium, the paywall blocks interaction. We wait for
    /// StoreKit to finish loading entitlements so premium users never see a
    /// flash of the paywall on launch.
    private var isLocked: Bool {
        
        print(store.isPremium)
        return store.hasLoadedEntitlements
            && metrics.count >= 1
            && !store.isPremium
    }

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingFlow(onComplete: {
                    hasCompletedOnboarding = true
                    PostHogSDK.shared.capture("onboading_completed")
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.5), value: hasCompletedOnboarding)
//        .sheet(isPresented: .constant(true)) {
//            PaywallView()
//        }
        .sheet(isPresented: .constant(isLocked)) {
            PaywallView()
        }
    }
}

#Preview("Onboarding") {
    RootView()
        .environment(MetricGenerator())
        .environment(Store()) 
        .modelContainer(for: Metric.self, inMemory: true)
}
 
