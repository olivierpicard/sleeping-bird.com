//
//  TimeRange.swift
//  ArperBird
//
//  Created by Olivier Picard on 03/05/2026.
//

import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case month = "1M"
    case sixMonths = "6M"
    case year = "1Y"

    var id: String { rawValue }

    var bucketComponent: Calendar.Component {
        switch self {
        case .month: return .day
        case .sixMonths: return .weekOfYear
        case .year: return .month
        }
    }

    var visibleDomainSeconds: TimeInterval {
        switch self {
        case .month: return 30 * 86_400
        case .sixMonths: return 26 * 7 * 86_400
        case .year: return 365 * 86_400
        }
    }

    var desiredAxisLabels: Int {
        switch self {
        case .month: return 8
        case .sixMonths: return 7
        case .year: return 6
        }
    }
}
