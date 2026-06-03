//
//  SleepingBirdApp.swift
//  SleepingBird
//
//  Created by Olivier Picard on 14/04/2026.
//

import FirebaseCore
import PostHog
import SwiftData
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let POSTHOG_PROJECT_TOKEN =
            "phc_rPp6UtzHioADKcqVuMVrs2rWi33wCVABLbSbMdPBVCf5"
        let POSTHOG_HOST = "https://eu.i.posthog.com"

        let config = PostHogConfig(
            projectToken: POSTHOG_PROJECT_TOKEN,
            host: POSTHOG_HOST
        )

        config.errorTrackingConfig.autoCapture = true
        PostHogSDK.shared.setup(config)

        #if DEBUG
            PostHogSDK.shared.register(["environment": "dev"])
        #else
            PostHogSDK.shared.register(["environment": "prod"])
        #endif

        FirebaseApp.configure()
        return true
    }
}

@main
struct SleepingBirdApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var generator = MetricGenerator()
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(generator)
                .environment(store)
        }
        .modelContainer(for: Metric.self)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await store.refreshPurchased() }
            }
        }
    }
}
