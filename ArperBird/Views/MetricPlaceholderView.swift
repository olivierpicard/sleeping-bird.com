//
//  MetricPlaceholderView.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import Charts
import SwiftUI

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.6), location: 0.5),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 2)
                    .offset(x: -w * 2 + phase * w * 3)
                }
                .clipped()
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.7).repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    fileprivate func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

struct MetricPlaceholderView: View {
    let data = [
        3000, 5000, 4000, 6500, 5500, 7000, 4500, 8000, 6000, 9000, 7500,
        8432,
    ]

    let mainColor = Color.primary.opacity(0.25)
    let secondColor = Color.primary.opacity(0.15)
    let thirdColor = Color.primary.opacity(0.1)

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(mainColor)
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading) {
                    Text("Placeholder")
                        .font(.caption)
                        .redacted(reason: .placeholder)
                    Text("Value")
                        .font(.system(size: 38))
                        .redacted(reason: .placeholder)
                }
                Spacer()
                Circle()
                    .foregroundStyle(mainColor)
                    .frame(width: 52)
            }

            RoundedRectangle(cornerRadius: 12)
                .frame(height: 100)
                .foregroundStyle(mainColor)
        }
        .padding()
        .shimmer()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1))
                .opacity(0.1)
        }
    }
}

#Preview {
    MetricPlaceholderView()
        .padding()
}
