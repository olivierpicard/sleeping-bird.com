//
//  _MetricEditorHelpers.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

func _meFormat(_ v: Double, step: Double) -> String {
    step >= 1 ? String(Int(v)) : String(format: "%.1f", v)
}

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
        case .ms: "ms"
        case .s: "sec"
        case .m: "min"
        case .h: "hr"
        }
    }
}

/// Returns the ordered list of units to display, from largest to smallest,
/// derived from the smallest granularity and the largest expected duration.
func _durationUnits(granularity: _DurationGranularity, maxInSeconds: Int) -> [_DurationGranularity] {
    let smallest = granularity
    let largest: _DurationGranularity = {
        if maxInSeconds >= 3600 { return .h }
        if maxInSeconds >= 60 { return .m }
        if maxInSeconds >= 1 { return .s }
        return .ms
    }()
    let top = max(largest.order, smallest.order)
    let bottom = smallest.order
    return [.h, .m, .s, .ms].filter { $0.order >= bottom && $0.order <= top }
}

/// Returns the upper bound (exclusive for non-top, inclusive cap for top) for a unit
/// given the overall maxInSeconds and whether it's the largest displayed unit.
func _durationUnitMax(_ unit: _DurationGranularity, maxInSeconds: Int, isTop: Bool) -> Int {
    if isTop {
        switch unit {
        case .h: return Swift.max(1, maxInSeconds / 3600)
        case .m: return Swift.max(1, maxInSeconds / 60)
        case .s: return Swift.max(1, maxInSeconds)
        case .ms: return Swift.max(1, maxInSeconds * 1000)
        }
    }
    switch unit {
    case .h: return 23
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

struct _SaveButton: View {
    let mainColor: Color
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Save")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? mainColor : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (isEnabled ? mainColor : Color.gray).opacity(0.4), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal)
    }
}
