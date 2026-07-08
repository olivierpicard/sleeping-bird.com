//
//  OnboardingFlow.swift
//  ArperBird
//
//  Created by Olivier Picard on 30/05/2026.
//

import SwiftUI

struct OnboardingFlow: View {
    var onComplete: () -> Void = {}

    // The welcome screen advances to the "type it, track it" demo, which
    // completes onboarding via its "Create my first tracker" button.
    // (`GuidedAnimation` — the older voice-themed loop — stays in the codebase
    // for reference but is no longer part of the flow.)
    @State private var showGuided = false

    var body: some View {
        if showGuided {
            TypeItDemo(onComplete: onComplete)
                .transition(.opacity)
        } else {
            StartView(onStart: { withAnimation { showGuided = true } })
                .transition(.opacity)
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(\.locale, Locale(identifier: "es"))
}
