//
//  FakeMetric.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import Foundation

    extension Metric {
        static func fakeData(for config: MetricConfig, days: Int = 14)
            -> [DataPoint]
        {
            let now = Date()
            let calendar = Calendar.current
            return (0..<days).reversed().map { offset in
                let date =
                    calendar.date(byAdding: .day, value: -offset, to: now)
                    ?? now
                switch config {
                case .number(let cfg):
                    let range = cfg.max - cfg.min
                    let value = cfg.min + Double.random(in: 0...1) * range
                    let snapped =
                        (value / cfg.granularity).rounded() * cfg.granularity
                    return .number(date, min(snapped, cfg.max))
                case .categorySingleChoice(let cfg),
                    .categoryMultipleChoice(let cfg):
                    let count =
                        config.isMultiple
                        ? Int.random(in: 1...min(3, cfg.labels.count)) : 1
                    let picked = Array(cfg.labels.shuffled().prefix(count))
                    return .category(date, picked)
                case .binary:
                    return .binary(date, Double.random(in: 0...1) > 0.3)
                case .duration:
                    // No per-metric max any more; sample a plausible activity
                    // length (~40min–2h) so the reveal chart looks alive.
                    let max: TimeInterval = 2 * 3600
                    return .duration(
                        date,
                        TimeInterval.random(in: max * 0.3...max)
                    )
                case .datetime:
                    let randomOffset = TimeInterval.random(
                        in: 0...(60 * 60 * 24 * 30 * 6)
                    )
                    return .datetime(date.addingTimeInterval(-randomOffset))
                }
            }
        }
    }

    extension MetricConfig {
        fileprivate var isMultiple: Bool {
            if case .categoryMultipleChoice = self { return true }
            return false
        }
    }
