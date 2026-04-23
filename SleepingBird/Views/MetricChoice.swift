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
                    ForEach(suggestions, id: \.name) { suggestion in
                        MetricView(
                            title: suggestion.name,
                            emoji: suggestion.emoji,
                            value: "2 345",
                            mainColor: .blue,
                            data: [
                                3000, 5000, 4000, 6500, 5500, 7000, 4500, 8000,
                                6000, 9000, 7500,
                                8432,
                            ],
                            hideAddButton: true
                        ).padding()
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
                .Mock.number(title: "My Steps"),
                .Mock.categorySingle(),
                .Mock.binary(),
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
