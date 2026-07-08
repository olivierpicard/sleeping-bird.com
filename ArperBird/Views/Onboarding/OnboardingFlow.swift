//
//  OnboardingFlow.swift
//  ArperBird
//
//  Created by Olivier Picard on 30/05/2026.
//

import SwiftUI

struct OnboardingFlow: View {
    var onComplete: () -> Void = {}

    var body: some View {
        // The guided animation (`GuidedAnimation`) is intentionally unwired from
        // the flow for now; the welcome screen completes onboarding directly.
        StartView(onStart: onComplete)
    }
}

#Preview {
    OnboardingFlow()
        .environment(\.locale, Locale(identifier: "es"))
}
