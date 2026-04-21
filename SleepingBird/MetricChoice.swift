//
//  MetricChoice.swift
//  SleepingBird
//
//  Created by Olivier Picard on 20/04/2026.
//

import SwiftUI

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: isAnimating ? geo.size.width * 1.5 : -geo.size.width)
                    .allowsHitTesting(false)
                }
                .clipped()
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

private extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Card

private struct MetricSuggestionSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("✦ 95% match")
                .font(.subheadline)

            Text("Loading Metric Name Here")
                .font(.title)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Loading detail line one")
                Text("Loading secondary detail")
                Text("Another detail line here")
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .shimmer()
    }
}

// MARK: - Suggestion Card

private struct MetricSuggestionCard: View {
    let suggestion: MetricSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                Text("\(Int(suggestion.fitPercentage * 100))% match")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(suggestion.name)
                .font(.title)
                .fontWeight(.semibold)

            configView

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var configView: some View {
        switch suggestion.config {
        case .number(let config):
            VStack(alignment: .leading, spacing: 6) {
                Label("Number", systemImage: "number")
                if let unit = config.unit {
                    Text("Unit: \(unit)").foregroundStyle(.secondary)
                }
                Text("Range: \(Int(config.min)) – \(Int(config.max))").foregroundStyle(.secondary)
                if let goal = config.goal {
                    Text("Goal: \(Int(goal))").foregroundStyle(.secondary)
                }
            }
        case .categorySingleChoice(let config):
            VStack(alignment: .leading, spacing: 6) {
                Label("Single Choice", systemImage: "list.bullet")
                Text(config.labels.joined(separator: ", ")).foregroundStyle(.secondary)
            }
        case .categoryMultipleChoice(let config):
            VStack(alignment: .leading, spacing: 6) {
                Label("Multiple Choice", systemImage: "checklist")
                Text(config.labels.joined(separator: ", ")).foregroundStyle(.secondary)
            }
        case .binary(let config):
            Label("\(config.trueLabel) / \(config.falseLabel)", systemImage: "toggle.on")
        case .datetime:
            Label("Date & Time", systemImage: "clock")
        case .duration(let config):
            VStack(alignment: .leading, spacing: 6) {
                Label("Duration", systemImage: "timer")
                Text("Granularity: \(config.granularity)").foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - MetricChoice

struct MetricChoice: View {
    @Environment(\.dismiss) private var dismiss
    let instruction: String
    @State private var suggestions: [MetricSuggestion]
    @State private var isLoading: Bool

    init(instruction: String, suggestions: [MetricSuggestion] = []) {
        self.instruction = instruction
        self.suggestions = suggestions
        self._isLoading = State(initialValue: suggestions.isEmpty)
    }

    var body: some View {
        TabView {
            if isLoading {
                ForEach(0..<3, id: \.self) { _ in
                    MetricSuggestionSkeletonCard()
                }
            } else {
                ForEach(suggestions, id: \.name) { suggestion in
                    MetricSuggestionCard(suggestion: suggestion)
                }
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: { }) {
                    Image(systemName: "checkmark")
                }.buttonStyle(.glassProminent)
            }
        }
        .task {
            guard
                ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
            else { return }
            do {
                let response = try await AiSuggestMetric().generate(
                    userInstruction: instruction
                )
                suggestions = response.suggestions
                isLoading = false
            } catch {
                print(error)
                isLoading = false
            }
        }
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

