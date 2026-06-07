//
//  View+TrackScreen.swift
//  ArperBird
//
//  Created by Olivier Picard on 04/06/2026.
//

import PostHog
import SwiftUI

extension View {
    /// Records a PostHog `$screen` event each time the view appears.
    ///
    /// Use this on the top-level view of a screen. Unlike `capture`, screen
    /// events feed PostHog's Screens dashboard and tag subsequent events with
    /// `$screen_name`. SwiftUI has no view-controller lifecycle for PostHog to
    /// auto-capture, so screens are tracked manually here.
    func trackScreen(
        _ name: String,
        _ properties: [String: Any]? = nil
    ) -> some View {
        onAppear { PostHogSDK.shared.screen(name, properties: properties) }
    }
}
