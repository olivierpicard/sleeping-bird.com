//
//  _CategorySingleEditor.swift
//  ArperBird
//
//  Created by Olivier Picard on 01/05/2026.
//

import SwiftUI

struct _CategorySingleEditor: View {
    let labels: [String]
    let mainColor: Color
    let onAdd: (String) -> Void

    @State private var selectedLabel: String?
    @State private var contentHeight: CGFloat = .zero

    var body: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(spacing: 12) {

                    ForEach(labels, id: \.self) { label in
                        Button(action: {
                            selectedLabel = label
                        }) {
                            HStack {
                                Text(label)
                                    .font(.headline)
                                    .foregroundStyle(
                                        selectedLabel == label
                                            ? mainColor : .primary
                                    )

                                Spacer()

                                if selectedLabel == label {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(mainColor)
                                } else {
                                    Image(systemName: "circle")
                                        .font(.title3)
                                        .foregroundStyle(
                                            .secondary.opacity(0.5)
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 60)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        selectedLabel == label
                                            ? mainColor.opacity(0.1)
                                            : Color(.secondarySystemBackground)
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        selectedLabel == label
                                            ? mainColor : Color.clear,
                                        lineWidth: 2
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: selectedLabel)
                        .padding(.horizontal)
                    }
                }
            }
            .scrollIndicators(.visible)

            _SaveButton(mainColor: mainColor, isEnabled: selectedLabel != nil) {
                if let selectedLabel {
                    onAdd(selectedLabel)
                }
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
            _CategorySingleEditor(
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
            _CategorySingleEditor(
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
            _CategorySingleEditor(
                labels: [
                    "Happy", "Neutral", "Sad", "Angry", "Excited", "Happy2",
                    "Neutral2", "Sad2", "Angry2", "Excited2",
                ],
                mainColor: .orange,
                onAdd: { _ in }
            )
        }
}
