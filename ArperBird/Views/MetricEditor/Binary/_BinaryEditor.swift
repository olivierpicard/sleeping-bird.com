//
//  _BinaryEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 01/05/2026.
//

import SwiftUI

struct _BinaryEditor: View {
    let trueLabel: String
    let falseLabel: String
    let mainColor: Color
    let onAdd: (Bool) -> Void

    @State private var selection: Bool?

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                choiceCard(
                    label: trueLabel,
                    icon: "hand.thumbsup.fill",
                    value: true
                )
                choiceCard(
                    label: falseLabel,
                    icon: "hand.thumbsdown.fill",
                    value: false
                )
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity)

            _SaveButton(mainColor: mainColor, isEnabled: selection != nil) {
                if let selection {
                    onAdd(selection)
                }
            }
        }
        .padding(.vertical, 24)
        .presentationBackground(.windowBackground)
        .presentationDetents([.height(280)])
    }

    @ViewBuilder
    private func choiceCard(label: String, icon: String, value: Bool) -> some View {
        let isSelected = selection == value

        Button(action: { selection = value }) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : mainColor)

                Text(label)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isSelected
                            ? mainColor
                            : Color(.secondarySystemBackground)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isSelected ? mainColor : Color.clear,
                        lineWidth: 2
                    )
            }
            .shadow(
                color: isSelected ? mainColor.opacity(0.3) : .clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview("Yes / No") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _BinaryEditor(
                trueLabel: "Yes",
                falseLabel: "No",
                mainColor: .orange,
                onAdd: { _ in }
            )
        }
}

#Preview("Long labels") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _BinaryEditor(
                trueLabel: "Worked out at the gym",
                falseLabel: "Skipped today the gym day",
                mainColor: .green,
                onAdd: { _ in }
            )
        }
}
