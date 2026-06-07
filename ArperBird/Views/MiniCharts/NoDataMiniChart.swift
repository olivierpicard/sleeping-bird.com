//
//  NoData.swift
//  ArperBird
//
//  Created by Olivier Picard on 27/04/2026.
//

import SwiftUI

struct NoDataMiniChart: MiniChart {
    @Environment(\.colorScheme) private var colorScheme
    let color: Color = Color.gray
    
    private let totalDays = 15
    private let data: [Double]
    private var opacity: Double  {colorScheme == .dark ? 0.3 : 0.15 }

    init() {
        self.data = (0..<totalDays).map { _ in
            return Double.random(in: 10...50)
        }
    }

    var body: some View {
        ZStack {
            LineMiniChart(data: data, color: color.opacity(opacity))

            VStack(spacing: 2) {
                Text("No data yet")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Add your first value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

        }
    }
}

#Preview {
    NoDataMiniChart()
        .frame(height: 100)

}

//#Preview("With colors") {
//    VStack {
//        NoDataMiniChart(color: .pink)
//            .frame(height: 100)
//        NoDataMiniChart(color: .orange)
//            .frame(height: 100)
//        NoDataMiniChart(color: .blue)
//            .frame(height: 100)
//        NoDataMiniChart(color: .yellow)
//            .frame(height: 100)
//        NoDataMiniChart(color: .green)
//            .frame(height: 100)
//    }
//
//}
