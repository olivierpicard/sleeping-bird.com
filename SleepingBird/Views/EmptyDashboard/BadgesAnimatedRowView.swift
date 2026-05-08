//
//  BadgesAnimatedRowView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 07/05/2026.
//

import SwiftUI

struct BadgesAnimatedRowView: View {
    let textList: [String]
    let innerPadding: Double
    let borderThickness: Double
    let borderColor: Color
    let maxCount: Int?
    let swapInterval: TimeInterval
    let sequentialSwap: Bool
    let horizontalSlide: Bool

    @State private var visibleItems: [String] = []
    @State private var nextIndex: Int = 0
    @State private var slideItems: [SlideItem] = []
    @State private var nextSlideId: Int = 0

    private struct SlideItem: Identifiable, Equatable {
        let id: Int
        let text: String
    }

    init(
        textList: [String],
        innerPadding: Double = 10,
        borderThickness: Double = 1,
        borderColor: Color = Color.gray,
        maxCount: Int? = 7,
        swapInterval: TimeInterval = 2.5,
        sequentialSwap: Bool = false,
        horizontalSlide: Bool = false
    ) {
        self.textList = textList
        self.innerPadding = innerPadding
        self.borderThickness = borderThickness
        self.borderColor = borderColor
        self.maxCount = maxCount
        self.swapInterval = swapInterval
        self.sequentialSwap = sequentialSwap
        self.horizontalSlide = horizontalSlide

        let initial: [String]
        if horizontalSlide {
            initial = textList
        } else if let maxCount, maxCount < textList.count {
            initial = Array(textList.prefix(maxCount))
        } else {
            initial = textList
        }
        _visibleItems = State(initialValue: initial)
        _nextIndex = State(initialValue: initial.count)

        let slides = initial.enumerated().map { SlideItem(id: $0.offset, text: $0.element) }
        _slideItems = State(initialValue: slides)
        _nextSlideId = State(initialValue: slides.count)
    }

    private var canSwap: Bool {
        if horizontalSlide { return textList.count > 1 }
        guard let maxCount else { return false }
        return textList.count > maxCount
    }

    private var initialItems: [String] {
        if horizontalSlide { return textList }
        guard let maxCount, maxCount < textList.count else { return textList }
        return Array(textList.prefix(maxCount))
    }

    @ViewBuilder
    private func badge(_ item: String) -> some View {
        Text(item)
            .padding(.all, innerPadding)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: borderThickness)
            }
    }

    var body: some View {
        Group {
            if horizontalSlide {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(slideItems) { item in
                            badge(item.text)
                                .transition(.asymmetric(
                                    insertion: .identity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: slideItems)
                }
                .scrollDisabled(true)
            } else {
                WrappingHStack(hSpacing: 20, vSpacing: 10) {
                    ForEach(visibleItems, id: \.self) { item in
                        badge(item)
                            .transition(.opacity)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: visibleItems)
        .task {
            guard canSwap else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(swapInterval * 1_000_000_000))
                if Task.isCancelled { break }
                swap()
            }
        }
    }

    private func swap() {
        if horizontalSlide {
            guard !slideItems.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                let first = slideItems.removeFirst()
                slideItems.append(SlideItem(id: nextSlideId, text: first.text))
            }
            nextSlideId += 1
            return
        }
        if sequentialSwap {
            guard !visibleItems.isEmpty, !textList.isEmpty else { return }
            let newItem = textList[nextIndex % textList.count]
            withAnimation(.easeInOut(duration: 0.4)) {
                visibleItems.removeFirst()
                visibleItems.append(newItem)
            }
            nextIndex += 1
        } else {
            let hidden = textList.filter { !visibleItems.contains($0) }
            guard let newItem = hidden.randomElement(),
                  let replaceIndex = visibleItems.indices.randomElement() else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                visibleItems[replaceIndex] = newItem
            }
        }
    }
}

private struct WrappingHStack: Layout {
    var hSpacing: CGFloat = 20
    var vSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + vSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - hSpacing)
        }

        return CGSize(width: totalWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + vSpacing
                x = 0
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    BadgesAnimatedRowView(textList: [
        "Water",
        "Sleeps",
        "Pain",
        "Belly Size",
        "Poop consistency",
        "Mood",
        "Meditation duration",
        "Time spend outside",
        "Call booked",
        "Coffee intake",
        "Time with kids",
        "Angry count",
        "Meat ate",
        "Car cost",
    ])
}

#Preview("Sequential") {
    BadgesAnimatedRowView(textList: [
        "Water",
        "Sleeps",
        "Pain",
        "Belly Size",
        "Poop consistency",
        "Mood",
        "Meditation duration",
        "Time spend outside",
        "Call booked",
        "Coffee intake",
        "Time with kids",
        "Angry count",
        "Meat ate",
        "Car cost",
    ],
    sequentialSwap: true)
}

#Preview("Horizontal Slide") {
    BadgesAnimatedRowView(textList: [
        "Water",
        "Sleeps",
        "Pain",
        "Belly Size",
        "Poop consistency",
        "Mood",
        "Meditation duration",
        "Time spend outside",
        "Call booked",
        "Coffee intake",
        "Time with kids",
        "Angry count",
        "Meat ate",
        "Car cost",
    ],
    horizontalSlide: true)
    .padding(.leading)
}
