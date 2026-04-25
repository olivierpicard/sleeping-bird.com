//
//  MetricStore.swift
//  SleepingBird
//
//  Created by Olivier Picard on 24/04/2026.
//

import Foundation

@Observable
class MetricStore {
    private(set) var store: [Metric] = []
    private(set) var isGenerating: Bool = false

    init(with fakeMetric: [Metric] = []) {
        store.append(contentsOf: fakeMetric)
    }

    func create(instruction: String) {
        Task {
            isGenerating = true
            defer { isGenerating = false }

            do {
                try await Task.sleep(for: .seconds(2))
                print("awaiting is over -- metric created")
                store.append(
                    Metric(
                        from: MetricSchema.Mock.number(
                            title: "Daily Steps",
                            emoji: "👟"
                        )
                    ),
                )
                //                let response = try await AiSuggestMetric().generate(
                //                    userInstruction: instruction
                //                )
                //                store.append(response)
            } catch {
                print("Can't create the metric: \(error)")
            }
        }
    }
}
