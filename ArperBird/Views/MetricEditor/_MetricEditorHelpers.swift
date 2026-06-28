//
//  _MetricEditorHelpers.swift
//  ArperBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

func _meFormat(_ v: Double, step: Double) -> String {
    let decimals = _meDecimals(for: step)
    return decimals == 0 ? String(Int(v)) : String(format: "%.\(decimals)f", v)
}

/// Number of decimal places implied by `step` (0.25 → 2, 0.1 → 1, 1 → 0).
private func _meDecimals(for step: Double) -> Int {
    guard step > 0 else { return 0 }
    var scaled = step
    var decimals = 0
    while abs(scaled.rounded() - scaled) > 1e-9 && decimals < 10 {
        scaled *= 10
        decimals += 1
    }
    return decimals
}

struct _SaveButton: View {
    let mainColor: Color
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("metric_editor.save")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? mainColor : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (isEnabled ? mainColor : Color.gray).opacity(0.4), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal)
    }
}
