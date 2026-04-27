//
//  NoData.swift
//  SleepingBird
//
//  Created by Olivier Picard on 27/04/2026.
//

import SwiftUI

struct NoDataMiniChart: MiniChart {
    @Environment(\.colorScheme) private var colorScheme
    let color: Color
    
    private let totalDays = 15
    private let data: [Double]
    private var opacity: Double  {colorScheme == .dark ? 0.3 : 0.1 }

    init(color: Color) {
        self.data = (0..<totalDays).map { _ in
            return Double.random(in: 10...50)
        }
        self.color = color
    }

    var body: some View {
        ZStack {
            LineMiniChart(data: data, color: color.opacity(opacity))

            Text("Not enough data")

        }
    }
}

#Preview {
    NoDataMiniChart(color: .gray)
        .frame(height: 100)

}

#Preview("With colors") {
    VStack {
        NoDataMiniChart(color: .pink)
            .frame(height: 100)
        NoDataMiniChart(color: .orange)
            .frame(height: 100)
        NoDataMiniChart(color: .blue)
            .frame(height: 100)
        NoDataMiniChart(color: .yellow)
            .frame(height: 100)
        NoDataMiniChart(color: .green)
            .frame(height: 100)
    }

}
