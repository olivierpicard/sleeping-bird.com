//
//  _MetricEditorHelpers.swift
//  SleepingBird
//
//  Created by Olivier Picard on 30/04/2026.
//

import SwiftUI

func _meFormat(_ v: Double, step: Double) -> String {
    step >= 1 ? String(Int(v)) : String(format: "%.1f", v)
}

struct _SaveButton: View {
    let mainColor: Color
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Save")
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
