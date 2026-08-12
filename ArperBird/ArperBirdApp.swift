//
//  ArperBirdApp.swift
//  ArperBird
//
//  Created by Olivier Picard on 14/04/2026.
//

import FirebaseCore
import PostHog
import RevenueCat
import SwiftData
import SwiftUI
import TipKit
import FirebaseAppCheck

class AppCheckReleaseProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    #if DEBUG
      return AppCheckDebugProvider(app: app)
    #else
      return AppAttestProvider(app: app)
    #endif
  }
}

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

        let providerFactory = AppCheckReleaseProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        FirebaseApp.configure()
        return true
    }
}


@main
struct ArperBirdApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var generator = MetricGenerator()
    @State private var store = Store()

    /// Persistent SwiftData container built with an explicit `VersionedSchema`
    /// and `SchemaMigrationPlan` so user data survives App Store updates
    /// deterministically, instead of relying on implicit lightweight migration.
    private let modelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: MetricMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        Purchases.configure(
            with: Configuration.Builder(
                withAPIKey: "appl_AcawmFKcLsssZrqzjhIjDDbevCS"
            )
            .with(appUserID: UniqueIdentityStore().get())
            .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
            .build()
        )

        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault),
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(generator)
                .environment(store)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Both are pull-only snapshots, and a foreground is exactly when
                // they may have gone stale: the user could have subscribed,
                // cancelled, refunded or redeemed an offer in the App Store while
                // away. Refreshing entitlements alone would leave the paywall
                // offering a free trial the user has since consumed.
                Task {
                    await store.refreshPurchased()
                    await store.refreshIntroEligibility()
                }
            }
        }
    }
}
