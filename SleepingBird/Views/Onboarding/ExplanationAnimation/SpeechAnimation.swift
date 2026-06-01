//
//  SpeechAnimation.swift
//  SleepingBird
//
//  Created by Olivier Picard on 01/06/2026.
//

import SwiftUI

struct SpeechAnimation: View {
    let text: String
    /// Delay between each revealed word, in seconds.
    var wordInterval: TimeInterval = 0.25

    private let font: Font = .body.weight(.medium)
    private let horizontalPadding: CGFloat = 24
    private let verticalPadding: CGFloat = 18
    private let lineSpacing: CGFloat = 4

    @State private var revealedWordCount = 0
    @State private var wordSizes: [Int: CGSize] = [:]
    @State private var spacePairWidth: CGFloat = 0
    @State private var spaceSingleWidth: CGFloat = 0
    @State private var availableWidth: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    private var words: [String] {
        text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }

    private var spaceWidth: CGFloat {
        max(0, spacePairWidth - spaceSingleWidth)
    }

    /// Max width the text can occupy inside the bubble (bubble width minus padding).
    private var textBudget: CGFloat {
        max(0, availableWidth - horizontalPadding * 2)
    }

    /// Greedily packs word indices into lines that fit within `textBudget`.
    private var lines: [[Int]] {
        guard !wordSizes.isEmpty, textBudget > 0 else { return [Array(words.indices)] }
        var result: [[Int]] = []
        var current: [Int] = []
        var width: CGFloat = 0
        for i in words.indices {
            let w = wordSizes[i]?.width ?? 0
            let add = current.isEmpty ? w : spaceWidth + w
            if !current.isEmpty && width + add > textBudget {
                result.append(current)
                current = [i]
                width = w
            } else {
                current.append(i)
                width += add
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Only the lines that contain at least one revealed word.
    private var visibleLines: [[Int]] {
        lines.filter { revealedCount(in: $0) > 0 }
    }

    var body: some View {
        bubble
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { availableWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, newValue in
                            availableWidth = newValue
                        }
                }
            )
            .background(measuringOverlay)
            .onAppear { startAnimation() }
            .onDisappear { animationTask?.cancel() }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(visibleLines, id: \.first) { line in
                lineView(line)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: revealedWordCount)
    }

    /// A single line: full text laid out, clipped to the revealed width.
    private func lineView(_ line: [Int]) -> some View {
        let fullText = line.map { words[$0] }.joined(separator: " ")
        let width = revealedWidth(in: line)
        return Text(fullText)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .frame(width: width, alignment: .leading)
            .clipped()
    }

    /// Hidden views measuring each word's width and the width of a space.
    private var measuringOverlay: some View {
        ZStack {
            ForEach(words.indices, id: \.self) { i in
                Text(words[i])
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear { wordSizes[i] = geo.size }
                        }
                    )
            }
            Text("x x")
                .font(font)
                .fixedSize()
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { spacePairWidth = geo.size.width }
                    }
                )
            Text("xx")
                .font(font)
                .fixedSize()
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { spaceSingleWidth = geo.size.width }
                    }
                )
        }
        .hidden()
    }

    /// How many words of `line` are currently revealed.
    private func revealedCount(in line: [Int]) -> Int {
        guard let first = line.first else { return 0 }
        return max(0, min(line.count, revealedWordCount - first))
    }

    /// Cumulative width of the revealed words within `line`.
    private func revealedWidth(in line: [Int]) -> CGFloat {
        let count = revealedCount(in: line)
        guard count > 0 else { return 0 }
        var width: CGFloat = 0
        for (i, index) in line.prefix(count).enumerated() {
            let w = wordSizes[index]?.width ?? 0
            width += i == 0 ? w : spaceWidth + w
        }
        return width
    }

    private func startAnimation() {
        revealedWordCount = 0
        animationTask?.cancel()
        animationTask = Task {
            let count = words.count
            for i in 0..<count {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: UInt64(wordInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run { revealedWordCount = i + 1 }
            }
        }
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        VStack(spacing: 32) {
            SpeechAnimation(
                text: "Grocery shopping $80.000",
                wordInterval: 0.35
            )
            SpeechAnimation(
                text: "I went for a 45 minute run this morning before breakfast and felt great",
                wordInterval: 0.2
            )
        }
        .padding(.horizontal, 24)
    }
}
