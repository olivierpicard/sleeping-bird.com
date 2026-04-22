//
//  TrackerView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 21/04/2026.
//

import Charts
import SwiftUI

struct MetricView: View {
    let title: String
    let emoji: String
    let value: String
    let mainColor: Color
    var data: [Double] = []
    @State private var emojiSize: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(emoji)
                    .font(.system(size: emojiSize * 0.5))
                    .frame(width: emojiSize, height: emojiSize)
                    .background {
                        mainColor.opacity(0.03)
                            .background(.ultraThinMaterial)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(mainColor.opacity(0.4), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text(title.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 38))
                        .fontWeight(.light)
                }
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    emojiSize = $0
                }
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: emojiSize*0.8, height: emojiSize*0.8)
                .background(mainColor)
                .clipShape(Circle())
                .shadow(
                    color: mainColor.opacity(0.6),
                    radius: 10,
                    x: 0,
                    y: 3
                )
                .buttonStyle(.plain)

            }
            .padding(.horizontal)
            .padding(.top, 23)

            if !data.isEmpty {
                Chart {
                    ForEach(Array(data.enumerated()), id: \.offset) {
                        index,
                        value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(mainColor)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Index", index),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                stops: [
                                    .init(color: mainColor.opacity(0.35), location: 0),
                                    .init(color: mainColor.opacity(0), location: 0.8),
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

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(mainColor.opacity(0.1), lineWidth: 1)
        )

    }
}

#Preview {
    MetricView(
        title: "Daily Steps",
        emoji: "👟",
        value: "8,432",
        mainColor: .green,
        data: [
            3000, 5000, 4000, 6500, 5500, 7000, 4500, 8000, 6000, 9000, 7500,
            8432,
        ]
    )
    .padding()
}
