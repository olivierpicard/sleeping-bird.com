//
//  MetricStore.swift
//  SleepingBird
//
//  Created by Olivier Picard on 24/04/2026.
//

import Foundation

@Observable
class MetricStore {
    private(set) var metrics: [Metric] = []
    private(set) var isGenerating: Bool = false

    init(with fakeMetric: [Metric] = [], isGenerating: Bool = false) {
        metrics.append(contentsOf: fakeMetric)
        self.isGenerating = isGenerating
    }

    func create(instruction: String) {
        Task {
            isGenerating = true
            defer { isGenerating = false }

            do {
                try await Task.sleep(for: .seconds(2))
                print("awaiting is over -- metric created")

                let fakeSchema = MetricSchema.Fake.number(
                    title: "Daily Steps",
                    emoji: "👟"
                )

                let fakeData = Metric.fakeData(for: fakeSchema.config)

                metrics.append(
                    Metric(from: fakeSchema, data: fakeData),
                )
                //                let response = try await AiMetricSuggestion().generate(
                //                    userInstruction: instruction
                //                )
                //                metrics.append(response)
            } catch {
                print("Can't create the metric: \(error)")
            }
        }
    }
}
