import Foundation
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

    func generate(instruction: String, into context: ModelContext) {
        let p = Pending(instruction: instruction)
        pending.append(p)
        Task { @MainActor in
            defer { pending.removeAll { $0.id == p.id } }
            do {
                let schema = try await AiMetricSuggestion().generate(
                    userInstruction: instruction
                )
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
            } catch {
                print("generation failed: \(error)")
            }
        }
    }
}
