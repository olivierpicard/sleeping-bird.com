//
//  MetricChoice.swift
//  SleepingBird
//
//  Created by Olivier Picard on 20/04/2026.
//

import SwiftUI

struct MetricChoice: View {
    @Environment(\.dismiss) private var dismiss
    let instruction: String
    let loadID: UUID?
    @State private var suggestions: [MetricSuggestion]
    @State private var isLoading: Bool

    init(
        instruction: String,
        suggestions: [MetricSuggestion] = [],
        loadID: UUID? = nil
    ) {
        self.instruction = instruction
        self.loadID = loadID
        self.suggestions = suggestions
        self.isLoading = suggestions.isEmpty
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView {
                    ForEach(Array(suggestions.enumerated()), id: \.element.name)
                    { index, suggestion in
                        MetricViewFactory.makeView(
                            from: suggestion,
                            colorIndex: index,
                            generateFakeData: false,
                            hideAddButton: true,
                        )
                        .padding()
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {}) {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.glassProminent)
                .disabled(isLoading)
            }
        }
        .task(id: loadID) {
            let isPreview =
                ProcessInfo.processInfo.environment[
                    "XCODE_RUNNING_FOR_PREVIEWS"
                ] == "1"
            guard !isPreview || loadID != nil else { return }
            await updateSuggestions()
        }
    }

    @MainActor func updateSuggestions() async {
        isLoading = true
        do {
            let response = try await AiSuggestMetric().generate(
                userInstruction: instruction
            )
            suggestions = response.suggestions
            print(suggestions)
            isLoading = false
        } catch {
            print(error)
            isLoading = false
        }
    }

    private func choicePages() {

    }
}

#Preview("Loading") {
    NavigationStack {
        MetricChoice(
            instruction: "I want a good coffee tracking app",
            suggestions: []
        )
    }
}
#Preview("Loaded") {
    NavigationStack {
        MetricChoice(
            instruction: "I want a good coffee tracking app",
            suggestions: [
                .Mock.number(
                    title: "Coffee Count",
                    emoji: "☕",
                    unit: "cups",
                    max: 20,
                    granularity: 1,
                    goal: nil,
                    behavior: .cumulative,
                    chart: .bar,
                    bucket: .daily,
                    method: .numerical(.sum)
                ),
                .Mock.number(
                    title: "Coffee Volume",
                    emoji: "🥤",
                    unit: "ml",
                    min: 0,
                    max: 2000,
                    granularity: 10,
                    goal: nil,
                    behavior: .cumulative,
                    chart: .line,
                    bucket: .daily,
                    method: .numerical(.sum)
                ),
                .Mock.categorySingle(
                    title: "Coffee Type",
                    emoji: "🥛",
                    labels: [
                        "Espresso", "Latte", "Americano", "Cappuccino",
                        "Cold Brew",
                    ],
                    chart: .pie,
                    bucket: nil,
                    method: .categorical(.distribution)
                ),
            ]
        )
    }
}

// MARK: - Test Suggestion LLM output Preview

struct DebugLLMView: View {
    var instruction: String
    @State private var loadID: UUID? = nil

    var body: some View {
        MetricChoice(instruction: instruction, loadID: loadID)
        Divider()
        Button(action: {
            loadID = UUID()
        }) {
            Text("Run Suggestion LLM")
        }.padding()
    }
}

#Preview("Debug - Test LLM") {
    DebugLLMView(instruction: "I want to know how much coffee do I drink")
}
