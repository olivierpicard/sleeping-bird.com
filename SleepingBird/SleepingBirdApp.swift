//
//  SleepingBirdApp.swift
//  SleepingBird
//
//  Created by Olivier Picard on 14/04/2026.
//

import FirebaseCore
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct SleepingBirdApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State var metricStore = MetricStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(metricStore)
        }
    }
}
