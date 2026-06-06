import Foundation
import PostHog
import SwiftData

@Observable
final class MetricGenerator {
    struct Pending: Identifiable {
        let id = UUID()
        let instruction: String
    }

    private(set) var pending: [Pending] = []

    init(pending: [Pending] = []) {
        self.pending = pending
    }

    func generate(
        instruction: String,
        into context: ModelContext,
        locale: Locale = .current
    ) {
        let p = Pending(instruction: instruction)
        pending.append(p)
        Task { @MainActor in
            defer { pending.removeAll { $0.id == p.id } }
            do {
                let start = ContinuousClock.now
                let schema = try await AiMetricSuggestion(locale: locale)
                    .generate(
                        userInstruction: instruction
                    )
                let elapsed = ContinuousClock.now - start
                let durationS = ((elapsed / .seconds(1)) * 10).rounded() / 10
                let metric = Metric(
                    from: schema
                )
                //                try await Task.sleep(for: .seconds(3))
                //                let schema = MetricSchema.Fake.number()
                //                let metric = Metric(
                //                    from: schema,
                //                    data: Metric.fakeData(for: schema.config)
                //                )
                context.insert(metric)
                let configJSON = (try? JSONEncoder().encode(schema.config))
                    .flatMap { String(data: $0, encoding: .utf8) }
                PostHogSDK.shared.capture(
                    "data_schema_generated",
                    properties: [
                        "duration_s": durationS,
                        "emoji": schema.emoji,
                        "config_type": schema.config.analyticsName,
                        "chart_type": "\(schema.visual.chart)",
                        "config_json": configJSON ?? "",
                    ]
                )
            } catch {
                PostHogSDK.shared.captureException(
                    error,
                    properties: ["instruction_length": instruction.count]
                )
            }
        }
    }
}
