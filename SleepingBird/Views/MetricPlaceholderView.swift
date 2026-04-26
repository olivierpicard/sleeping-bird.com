//
//  MetricPlaceholderView.swift
//  SleepingBird
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
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.5), location: 0.5),
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
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

private extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

struct MetricPlaceholderView: View {
    let data = [
        3000, 5000, 4000, 6500, 5500, 7000, 4500, 8000, 6000, 9000, 7500,
        8432,
    ]
    
    let mainColor = Color.black.opacity(0.1)
    let secondColor = Color.black.opacity(0.08)
    let thirdColor = Color.black.opacity(0.03)
    
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
            .padding()
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) {
                    index,
                    value in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(secondColor)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(
                                    color: thirdColor,
                                    location: 0
                                ),
                                .init(
                                    color: mainColor.opacity(0),
                                    location: 0.8
                                ),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: (data.min() ?? 0)...(data.max() ?? 1))
            .frame(height: 100)
        }
        .shimmer()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay{
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1))
                .opacity(0.1)
        }
    }
}

#Preview {
    MetricPlaceholderView()
}
