//
//  MiniChart.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/04/2026.
//

import Foundation
import SwiftUI

protocol MiniChart: View {
    /// Whether the card should inset this chart from its horizontal edges.
    /// Edge-to-edge charts (line, no-data) return false to run flush.
    var usesCardInset: Bool { get }
}

extension MiniChart {
    var usesCardInset: Bool { true }   // safe default: padded
}
