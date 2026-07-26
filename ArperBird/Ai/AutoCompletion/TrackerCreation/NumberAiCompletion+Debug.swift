//
//  NumberAiCompletion+Debug.swift
//  ArperBird
//
//  Lightweight harness to eyeball NumberAiCompletion output. DEBUG only.
//

#if DEBUG
import FirebaseCore
import SwiftUI

/// Tiny preview harness: type an instruction, tap Generate, read the result
/// in the Xcode console (and on screen). Runs the real Firebase AI call, so it
/// configures Firebase itself since the AppDelegate doesn't run in previews.
private struct NumberAiCompletionDebugView: View {
    @State private var instruction = "Track my body weight"
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
                let result = try await NumberAiCompletion()
                    .generate(for: instruction)
                let constraints = result.constraints.enumerated()
                    .map { i, c in
                        "[\(i)] \(c.unit ?? "—") — max \(c.typicalMax), step \(c.granularity)"
                    }
                    .joined(separator: "\n")
                let text = """
                    \(result.emoji) cumulative: \(result.isCumulative), \
                    bounded: \(result.isBounded)
                    \(constraints)
                    """
                print("NumberAiCompletion(\(instruction)):\n\(text)")
                output = text
            } catch {
                print("NumberAiCompletion error: \(error)")
                output = "Error: \(error)"
            }
        }
    }
}

#Preview {
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    return NumberAiCompletionDebugView() 
}
#endif
