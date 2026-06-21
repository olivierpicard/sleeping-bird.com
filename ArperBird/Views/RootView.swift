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

    @Environment(Store.self) private var store
    @Query private var metrics: [Metric]

    /// TESTING ONLY: force-presents the paywall a moment after launch.
    @State private var showPaywallForTesting = false

    /// The free allowance is one generated metric. Once the user has used it
    /// and is not premium, the paywall blocks interaction. We wait for
    /// StoreKit to finish loading entitlements so premium users never see a
    /// flash of the paywall on launch.
    private var isLocked: Bool {
        
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
                    PostHogSDK.shared.capture("onboarding_completed")
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.5), value: hasCompletedOnboarding)

        // Presentation is fully derived from `isLocked`: the paywall shows
        // whenever the free allowance is used up and gates its own dismissal on
        // a premium unlock. We ignore SwiftUI's dismissal writes (rather than
        // using `.constant`, whose dropped writes can desync presentation state)
        // so the sheet can't be swiped away while still locked.
        .sheet(isPresented: Binding(get: { isLocked }, set: { _ in })) {
            PaywallView()
        }
        .onChange(of: isLocked, initial: true) { _, locked in
            AddEntryTip.isPaywallPresented = locked
        }
    }
}

#Preview("Onboarding") {
    RootView()
        .environment(MetricGenerator())
        .environment(Store()) 
        .modelContainer(for: Metric.self, inMemory: true)
}
 
