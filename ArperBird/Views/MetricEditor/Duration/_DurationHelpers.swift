//
//  _DurationHelpers.swift
//  ArperBird
//
//  Created by Olivier Picard on 01/05/2026.
//

import Foundation

enum _DurationGranularity: String {
    case ms, s, m, h

    init(_ raw: String) {
        self = _DurationGranularity(rawValue: raw) ?? .s
    }

    var order: Int {
        switch self {
        case .ms: 0
        case .s: 1
        case .m: 2
        case .h: 3
        }
    }

    var shortLabel: String {
        switch self {
        case .ms: String(localized: "duration.unit.ms")
        case .s: String(localized: "duration.unit.s")
        case .m: String(localized: "duration.unit.min")
        case .h: String(localized: "duration.unit.h")
        }
    }
}

/// The units the wheel displays, largest to smallest. Always hours + minutes +
/// seconds: every duration a user tracks in this app (sleep, workouts, reading,
/// meditation) falls inside that range, so a fixed set covers all of them without
/// the floor/ceiling ever collapsing the wheel to a single unit. Sub-second (ms)
/// precision is intentionally out of scope.
func _durationUnits() -> [_DurationGranularity] {
    [.h, .m, .s]
}

/// The fixed upper bound of the hours wheel. Every duration this app tracks
/// (sleep, workouts, reading, meditation) fits inside a day, so the wheel caps
/// at 24h rather than deriving a per-metric max.
let _durationMaxHours = 24

/// The upper bound (inclusive) for a wheel unit. Hours cap at `_durationMaxHours`;
/// the smaller units roll over at their natural boundaries.
func _durationUnitMax(_ unit: _DurationGranularity) -> Int {
    switch unit {
    case .h: return _durationMaxHours
    case .m: return 59
    case .s: return 59
    case .ms: return 999
    }
}

func _durationComponents(
    from totalMs: Int,
    units: [_DurationGranularity]
) -> [_DurationGranularity: Int] {
    var remaining = Swift.max(0, totalMs)
    var out: [_DurationGranularity: Int] = [:]
    for unit in units {
        let unitMs: Int = {
            switch unit {
            case .h: 3_600_000
            case .m: 60_000
            case .s: 1_000
            case .ms: 1
            }
        }()
        let value = remaining / unitMs
        out[unit] = value
        remaining -= value * unitMs
    }
    return out
}

func _durationTotalMs(_ components: [_DurationGranularity: Int]) -> Int {
    var total = 0
    for (unit, value) in components {
        switch unit {
        case .h: total += value * 3_600_000
        case .m: total += value * 60_000
        case .s: total += value * 1_000
        case .ms: total += value
        }
    }
    return total
}
