//
//  OnboardingFlow.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/05/2026.
//

import SwiftUI

enum OnboardingStep: Hashable {
    case language
}

struct OnboardingFlow: View {
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            StartView { path.append(.language) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .language:
                        VoiceLanguageConfigView()
                    }
                }
        }
    }
}

#Preview {
    OnboardingFlow()
}
