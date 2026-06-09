//
//  AddEntryTip.swift
//  ArperBird
//
//  Created by Olivier Picard on 08/06/2026.
//

import TipKit

/// Guides the user to the per-card "+" button after they create their first
/// metric, so they discover how to add a data point by hand.
///
/// TipKit persists its dismissed state, so this is shown only once. It is
/// invalidated as soon as the button is tapped (see `MetricView`).
struct AddEntryTip: Tip {
    /// Flipped on after a short delay once a card is on screen, so the tip
    /// animates in only after the card has visually settled rather than
    /// appearing immediately.
    @Parameter static var hasSettled: Bool = false
    @Parameter static var isPaywallPresented: Bool = false

    var title: Text {
        Text("add_entry_tip.title")
    }

    var message: Text? {
        Text("add_entry_tip.message")
    }

    var image: Image? {
        Image(systemName: "hand.tap.fill")
    }

    var rules: [Rule] {
        #Rule(Self.$hasSettled) { $0 == true }
        #Rule(Self.$isPaywallPresented) { $0 == false }
    }
}
