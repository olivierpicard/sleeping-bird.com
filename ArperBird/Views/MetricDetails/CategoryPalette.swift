//
//  CategoryPalette.swift
//  ArperBird
//
//  The stable choice → color assignment shared by the category calendar's pies
//  (`DayPieFill`) and its legend (`CategoryLegend`). A choice's color is fixed by
//  its position in the metric's declared label list, so it never re-maps as the
//  user filters others — color memory holds. Colors are drawn from the Okabe–Ito
//  colorblind-safe palette and **cycle** past its length, so a metric with more
//  labels than colors reuses them rather than running out (two choices may then
//  share a color; the legend still disambiguates by name).
//

import SwiftUI

enum CategoryPalette {
    /// Okabe–Ito colorblind-safe qualitative palette with **black removed** — it
    /// isn't stable across light/dark, leaving 7 maximally-distinct colors.
    /// https://jfly.uni-koeln.de/color/
    static let okabeIto: [Color] = [
        Color(hex: "E69F00"),  // orange
        Color(hex: "56B4E9"),  // sky blue
        Color(hex: "009E73"),  // bluish green
        Color(hex: "F0E442"),  // yellow
        Color(hex: "0072B2"),  // blue
        Color(hex: "D55E00"),  // vermillion
        Color(hex: "CC79A7"),  // reddish purple
    ]

    /// Stable label → color for an ordered label list: each label keeps the
    /// palette color at its index (cycling past the palette length), forever and
    /// independent of which labels are currently shown.
    static func colors(for labels: [String]) -> [String: Color] {
        var map: [String: Color] = [:]
        for (i, label) in labels.enumerated() {
            map[label] = okabeIto[i % okabeIto.count]
        }
        return map
    }
}
