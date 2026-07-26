//
//  GoalAICompletion+Debug.swift
//  ArperBird
//
//  Lightweight harness to eyeball GoalAiCompletion output. DEBUG only.
//

#if DEBUG
import FirebaseCore
import SwiftUI

/// Tiny preview harness: type an instruction, tap Generate, read the result
/// in the Xcode console (and on screen). Runs the real Firebase AI call, so it
/// configures Firebase itself since the AppDelegate doesn't run in previews.
private struct GoalAiCompletionDebugView: View {
    @State private var instruction = "Water"
    @State private var output = ""
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Instruction", text: $instruction)
                .textFieldStyle(.roundedBorder)

            Button("Generate") { generate() }
                .disabled(isLoading)

            if isLoading { ProgressView() }

            ScrollView {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    private func generate() {
        isLoading = true
        output = ""
        Task {
            defer { isLoading = false }
            do {
                let result = try await GoalAiCompletion()
                    .generate(for: instruction)
                let text = result.goals.enumerated()
                    .map { i, g in
                        "[\(i)] \(g.dailyGoal) \(g.unit) (step \(g.granularity))"
                    }
                    .joined(separator: "\n")
                let summary = "\(result.emoji)\n\(text)"
                print("GoalAiCompletion(\(instruction)):\n\(summary)")
                output = summary
            } catch {
                print("GoalAiCompletion error: \(error)")
                output = "Error: \(error)"
            }
        }
    }
}

#Preview {
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    return GoalAiCompletionDebugView() 
}
#endif
