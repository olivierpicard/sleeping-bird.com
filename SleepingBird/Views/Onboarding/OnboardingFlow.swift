//
//  OnboardingFlow.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/05/2026.
//

import SwiftUI

enum OnboardingStep: Hashable {
    case language
    case microphone
    case guided
}

struct OnboardingFlow: View {
    var onComplete: () -> Void = {}

    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            StartView { path.append(.language) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .language:
                        VoiceLanguageConfigView { path.append(.microphone) }
                    case .microphone:
                        MicAuthorizationView { path.append(.guided) }
                    case .guided:
                        GuidedAnimation(onComplete: onComplete)
                    }
                }
        }
    }
}

#Preview {
    OnboardingFlow()
}
