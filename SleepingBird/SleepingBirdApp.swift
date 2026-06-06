//
//  SleepingBirdApp.swift
//  SleepingBird
//
//  Created by Olivier Picard on 14/04/2026.
//

import FirebaseCore
import PostHog
import RevenueCat
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

        config.captureScreenViews = false
        config.errorTrackingConfig.autoCapture = true
        PostHogSDK.shared.setup(config)
        
//        Purchases.shared.syncPurchases { (customerInfo, error) in
//            if let error = error {
//                print("Restore failed: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let customerInfo = customerInfo else { return }
//            
//            // 1. Check if they actually have the premium entitlement
//            if customerInfo.entitlements["premium"]?.isActive == true {
//                
//                // 2. THIS is the master ID across device changes
//                let masterRevenueCatUserID = customerInfo.originalAppUserId
//                let currentActiveUserID = Purchases.shared.appUserID
//                
//                print("The underlying master user ID is: \(masterRevenueCatUserID)")
//                print("The current session user ID is: \(currentActiveUserID)")
//                
//                // 3. Update your local state or map it to PostHog
////                self.alignIdentities(masterID: masterRevenueCatUserID)
//            }
//        }

        #if DEBUG
            PostHogSDK.shared.identify(
                UniqueIdentityStore().get(),
                userProperties: ["is_internal": true]
            )
            PostHogSDK.shared.register(["environment": "dev"])
        #else
            PostHogSDK.shared.identify(UniqueIdentityStore().get())
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

    init() {
        Purchases.configure(
            with: Configuration.Builder(
                withAPIKey: "appl_AcawmFKcLsssZrqzjhIjDDbevCS"
            )
            .with(appUserID: UniqueIdentityStore().get())
            .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
            .build()
        )
    }

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
