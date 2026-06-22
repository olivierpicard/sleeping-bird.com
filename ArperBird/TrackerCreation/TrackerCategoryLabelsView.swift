//
//  TrackerCategoryLabelsView.swift
//  ArperBird
//
//  Created by Olivier Picard on 22/06/2026.
//

import SwiftUI

/// Lets the user type their own category labels for a `choices` tracker. The row
/// styling mirrors `_CategorySingleEditor` so the screen reads as a WYSIWYG
/// preview of the picker the user will later tap through. Starts with two empty
/// rows and grows via the "Add category" button.
struct TrackerCategoryLabelsView: View {
    let color: Color
    var onNext: ([String]) -> Void

    /// Rotating placeholder pool so each empty row hints at a different, concrete
    /// example instead of repeating "Category".
    private static let placeholders = [
        "Happy", "Calm", "Tired", "Anxious", "Energetic", "Sad", "Excited",
        "Bored", "Stressed", "Grateful",
    ]

    /// Two starting rows, the minimum the picker needs to be meaningful.
    @State private var categories: [Category] = [Category(), Category()]
    @FocusState private var focused: UUID?

    init(
        color: Color = .accent,
        onNext: @escaping ([String]) -> Void = { _ in }
    ) {
        self.color = color
        self.onNext = onNext
    }

    /// Trimmed, non-empty labels in their on-screen order.
    private var filledLabels: [String] {
        categories
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Need at least two real labels, and no half-typed blanks left dangling.
    private var canContinue: Bool {
        filledLabels.count >= 2 && filledLabels.count == categories.count
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) {
                        index, category in
                        categoryRow(at: index, placeholder: placeholder(at: index))
                    }

                    addButton
                }
                .padding()
            }
            .scrollIndicators(.visible)

            Button(action: { onNext(filledLabels) }) {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glassProminent)
            .disabled(!canContinue)
            .padding()
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                focused = categories.first?.id
            }
        }
        .trackScreen("ManualTrackerCreationCategoryLabels")
        .navigationTitle("Add a tracker")
        .navigationSubtitle("What are the categories ?")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func categoryRow(at index: Int, placeholder: String) -> some View {
        let id = categories[index].id
        let isFilled = !categories[index].text
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        HStack(spacing: 12) {
            Circle()
                .fill(isFilled ? color : Color.secondary.opacity(0.3))
                .frame(width: 10, height: 10)

            TextField(placeholder, text: $categories[index].text)
                .font(.headline)
                .focused($focused, equals: id)
                .submitLabel(.next)

            if categories.count > 2 {
                Button(action: { remove(id: id) }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    focused == id ? color : Color.clear,
                    lineWidth: 2
                )
        }
    }

    private var addButton: some View {
        Button(action: addCategory) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Add category")
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .frame(height: 60)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        color.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func placeholder(at index: Int) -> String {
        Self.placeholders[index % Self.placeholders.count]
    }

    private func addCategory() {
        let new = Category()
        categories.append(new)
        focused = new.id
    }

    private func remove(id: UUID) {
        categories.removeAll { $0.id == id }
    }

    /// Stable identity keeps `TextField` bindings attached to the right row
    /// across inserts and deletes, even when two rows share the same text.
    private struct Category: Identifiable {
        let id = UUID()
        var text: String = ""
    }
}

#Preview {
    @Previewable @State var showSheet = true
    NavigationStack {
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            TrackerCategoryLabelsView()
        }
    }
    .presentationDetents([.large])
}
