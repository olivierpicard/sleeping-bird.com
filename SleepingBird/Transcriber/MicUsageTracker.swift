//
//  MicUsageTracker.swift
//  SleepingBird
//
//  Tracks cumulative microphone (transcription) usage to cap cost.
//  Live dictation streams to a paid speech API, so a session left
//  running — or repeated long sessions — can be expensive. This type
//  sums listening time over a rolling window and, once a budget is
//  exceeded, blocks the mic for a cooldown. The block is persisted in
//  UserDefaults so force-quitting the app cannot bypass it.
//

import Foundation

@Observable
final class MicUsageTracker {
    private struct Session: Codable {
        let endedAt: Date
        let duration: TimeInterval
    }

    /// Rolling window over which listening time is summed.
    let window: TimeInterval
    /// Maximum total listening time allowed within `window` before blocking.
    let budget: TimeInterval
    /// How long the mic stays blocked once the budget is exceeded.
    let cooldown: TimeInterval

    private let defaults: UserDefaults
    private let sessionsKey = "mic.usage.sessions"
    private let blockedUntilKey = "mic.usage.blockedUntil"

    private var sessions: [Session]
    private(set) var blockedUntil: Date?

    init(
        window: TimeInterval = 60*10,
        budget: TimeInterval = 180,
        cooldown: TimeInterval = 60*30,
        defaults: UserDefaults = .standard
    ) {
        self.window = window
        self.budget = budget
        self.cooldown = cooldown
        self.defaults = defaults

        if let data = defaults.data(forKey: sessionsKey),
            let decoded = try? JSONDecoder().decode([Session].self, from: data)
        {
            self.sessions = decoded
        } else {
            self.sessions = []
        }
        let stored = defaults.double(forKey: blockedUntilKey)
        self.blockedUntil =
            stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    var isBlocked: Bool {
        guard let blockedUntil else { return false }
        return blockedUntil > .now
    }

    /// Seconds remaining on the current block, or 0 if not blocked.
    var blockRemaining: TimeInterval {
        guard let blockedUntil, blockedUntil > .now else { return 0 }
        return blockedUntil.timeIntervalSinceNow
    }

    /// Whole minutes remaining on the block (rounded up, minimum 1 while
    /// blocked) — for display in the user-facing message.
    var blockRemainingMinutes: Int {
        guard isBlocked else { return 0 }
        return max(1, Int(ceil(blockRemaining / 60)))
    }

    /// Record a finished listening session. Returns `true` if this session
    /// pushed usage over budget and the mic is now blocked.
    @discardableResult
    func record(duration: TimeInterval) -> Bool {
        guard duration > 0 else { return isBlocked }
        sessions.append(Session(endedAt: .now, duration: duration))
        prune()
        persistSessions()

        let total = sessions.reduce(0) { $0 + $1.duration }
        if total >= budget {
            block()
            return true
        }
        return isBlocked
    }

    private func block() {
        let until = Date.now.addingTimeInterval(cooldown)
        blockedUntil = until
        defaults.set(until.timeIntervalSince1970, forKey: blockedUntilKey)
        // Start the next window fresh once the cooldown elapses.
        sessions = []
        persistSessions()
    }

    private func prune() {
        let cutoff = Date.now.addingTimeInterval(-window)
        sessions.removeAll { $0.endedAt < cutoff }
    }

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            defaults.set(data, forKey: sessionsKey)
        }
    }
}
