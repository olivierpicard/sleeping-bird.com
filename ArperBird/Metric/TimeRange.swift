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

extension TemporalBucket {
    /// The calendar component a bucket groups by — lets aggregation key off a
    /// metric's own period (daily, weekly, …) the same way `TimeRange` keys off
    /// its 1M/6M/1Y window.
    var bucketComponent: Calendar.Component {
        switch self {
        case .hourly: return .hour
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }
}
