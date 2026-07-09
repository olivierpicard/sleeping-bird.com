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
        StartView(onStart: onComplete)
    }
}

#Preview {
    OnboardingFlow()
        .environment(\.locale, Locale(identifier: "es"))
}
