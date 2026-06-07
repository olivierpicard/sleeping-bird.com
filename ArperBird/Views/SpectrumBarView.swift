//
//  SpectrumBarView.swift
//  SleepingBird
//

import SwiftUI

struct SpectrumBarView: View {
    @State private var viewModel: SpectrumViewModel

    private let barCount: Int
    private let maxBarHeight: CGFloat = 56

    init(
        viewModel: SpectrumViewModel = LiveSpectrumViewModel(),
        barCount: Int = 24
    ) {
        self.barCount = barCount
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(.tint)
                    .frame(width: 4, height: barHeight(for: i))
                    .opacity(0.85)
            }
        }
        .frame(height: maxBarHeight)
        .animation(.easeOut(duration: 0.08), value: viewModel.magnitudes)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard index < viewModel.magnitudes.count else { return 2 }
        let mag = CGFloat(viewModel.magnitudes[index])
        return max(2, mag * maxBarHeight)
    }
}
