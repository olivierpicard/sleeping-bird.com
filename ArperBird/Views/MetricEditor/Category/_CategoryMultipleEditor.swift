//
//  _CategoryMultipleEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 01/05/2026.
//

import SwiftUI

struct _CategoryMultipleEditor: View {
    let labels: [String]
    let mainColor: Color
    let onAdd: ([String]) -> Void

    @State private var selectedLabels: Set<String> = []

    var body: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(labels, id: \.self) { label in
                        let isSelected = selectedLabels.contains(label)
                        Button(action: {
                            if isSelected {
                                selectedLabels.remove(label)
                            } else {
                                selectedLabels.insert(label)
                            }
                        }) {
                            HStack {
                                Text(label)
                                    .font(.headline)
                                    .foregroundStyle(
                                        isSelected ? mainColor : .primary
                                    )

                                Spacer()

                                Image(
                                    systemName: isSelected
                                        ? "checkmark.square.fill" : "square" 
                                )
                                .font(.title3)
                                .foregroundStyle(
                                    isSelected
                                        ? mainColor : .secondary.opacity(0.5)
                                )
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 60)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        isSelected
                                            ? mainColor.opacity(0.1)
                                            : Color(.secondarySystemBackground)
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        isSelected ? mainColor : Color.clear,
                                        lineWidth: 2
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: isSelected)
                        .padding(.horizontal)
                    }
                }
            }
            .scrollIndicators(.visible)

            _SaveButton(
                mainColor: mainColor,
                isEnabled: !selectedLabels.isEmpty
            ) {
                onAdd(Array(selectedLabels))
            }
        }
        .padding(.vertical, 24)
        .presentationBackground(.windowBackground)
        .presentationDetents([.height(300), .medium])
    }
}

#Preview("5 items") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _CategoryMultipleEditor(
                labels: ["Happy", "Neutral", "Sad", "Angry", "Excited"],
                mainColor: .orange,
                onAdd: { _ in }
            )
        }
}

#Preview("2 items") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _CategoryMultipleEditor(
                labels: ["Happy", "Neutral"],
                mainColor: .orange,
                onAdd: { _ in }
            )
        }
}

#Preview("15 items") {
    @Previewable @State var isSheetPresented = true
    NavigationStack { Text("") }
        .sheet(isPresented: $isSheetPresented) {
            _CategoryMultipleEditor(
                labels: [
                    "Happy", "Neutral", "Sad", "Angry", "Excited", "Happy2",
                    "Neutral2", "Sad2", "Angry2", "Excited2",
                ],
                mainColor: .orange,
                onAdd: { _ in }
            )
        }
}
