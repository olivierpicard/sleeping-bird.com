//
//  SleepingBirdApp.swift
//  SleepingBird
//
//  Created by Olivier Picard on 14/04/2026.
//

import FirebaseCore
import SwiftData
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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var generator = MetricGenerator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(generator)
        }
        .modelContainer(for: Metric.self)
    }
}
