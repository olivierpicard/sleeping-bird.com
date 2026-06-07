//
//  ChartBin.swift
//  ArperBird
//
//  Created by Olivier Picard on 03/05/2026.
//

import Foundation

struct ChartBin: Identifiable {
    let date: Date
    let value: Double
    let count: Int

    var id: Date { date }
}
