//
//  MetricPlaceholderView.swift
//  SleepingBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import Charts
import SwiftUI

struct MetricPlaceholderView: View {
    let data = [
        3000, 5000, 4000, 6500, 5500, 7000, 4500, 8000, 6000, 9000, 7500,
        8432,
    ]

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(.gray.opacity(0.2))
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
                    .foregroundStyle(.gray.opacity(0.2))
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
                    .foregroundStyle(Color.gray.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(
                                    color: Color.gray.opacity(0.1),
                                    location: 0
                                ),
                                .init(
                                    color: Color.gray.opacity(0),
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
