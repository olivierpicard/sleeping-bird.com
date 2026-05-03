//
//  TimeRange.swift
//  SleepingBird
//
//  Created by Olivier Picard on 03/05/2026.
//

import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "1W"
    case month = "1M"
    case sixMonths = "6M"
    case year = "1Y"

    var id: String { rawValue }

    var bucketComponent: Calendar.Component {
        switch self {
        case .week, .month: return .day
        case .sixMonths: return .weekOfYear
        case .year: return .month
        }
    }

    var visibleBarCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .sixMonths: return 26
        case .year: return 12
        }
    }
}
