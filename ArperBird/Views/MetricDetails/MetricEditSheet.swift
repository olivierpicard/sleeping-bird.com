//
//  MetricEditSheet.swift
//  ArperBird
//

import SwiftUI

struct MetricEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var metric: Metric

    @State private var name: String
    @State private var emoji: String
    @State private var color: Color
    @FocusState private var focused: Field?

    /// Read-only: the unit is fixed at creation time, since changing it would
    /// require converting every historic data point.
    private let unit: String?

    enum Field { case name }

    private static let palette: [Color] = [
        Color(hex: "FF453A"), // red
        Color(hex: "FF2D96"), // magenta
        Color(hex: "E05A6E"), // coral
        Color(hex: "FF9F0A"), // orange
        Color(hex: "C27D00"), // amber
        Color(hex: "B8A000"), // gold
        Color(hex: "9DBF3C"), // lime
        Color(hex: "30D158"), // green
        Color(hex: "00B870"), // emerald
        Color(hex: "7B9E6C"), // sage
        Color(hex: "00C7BE"), // teal
        Color(hex: "0096A8"), // ocean
        Color(hex: "3197FF"), // blue
        Color(hex: "BF5AF2"), // purple
        Color(hex: "AC8E68"), // brown
    ]

    init(metric: Metric) {
        self.metric = metric
        _name = State(initialValue: metric.name)
        _emoji = State(initialValue: metric.emoji)
        _color = State(initialValue: metric.color)
        if case .number(let cfg) = metric.config, let unit = cfg.unit, !unit.isEmpty {
            self.unit = unit
        } else {
            self.unit = nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    fieldsCard
                    colorCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .trackScreen("MetricEdit")
            .navigationTitle("Edit metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(color)
                    .disabled(!isValid || !hasChanges)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .onAppear { focused = .name }
    }

    // MARK: - Header card

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 64, height: 64)
                EmojiInputField(text: $emoji)
                    .frame(width: 64, height: 64)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, color)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)).padding(2))
                    .offset(x: 2, y: 2)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayedName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let unit {
                    Text(verbatim: unit)
                        .font(.subheadline)
                        .foregroundStyle(color)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Fields card

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("metric_edit_sheet.field.name")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            TextField("metric_edit_sheet.placeholder.name", text: $name)
                .font(.body)
                .textFieldStyle(.plain)
                .focused($focused, equals: .name)
                .submitLabel(.done)
                .textInputAutocapitalization(.sentences)
                .onSubmit(save)
                .tint(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Color card

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COLOR")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Self.palette, id: \.hexString) { swatch in
                        colorSwatch(swatch)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func colorSwatch(_ swatch: Color) -> some View {
        let isSelected = swatch.hexString == color.hexString
        return Button {
            withAnimation(.snappy) { color = swatch }
        } label: {
            ZStack {
                Circle()
                    .fill(swatch)
                    .frame(width: 36, height: 36)
                if isSelected {
                    Circle()
                        .strokeBorder(swatch, lineWidth: 2.5)
                        .frame(width: 46, height: 46)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(swatch.hexString)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Helpers

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedName: String {
        trimmedName.isEmpty ? metric.name : trimmedName
    }

    private var displayedEmoji: String {
        emoji.isEmpty ? metric.emoji : emoji
    }

    private var isValid: Bool { !trimmedName.isEmpty && !displayedEmoji.isEmpty }

    private var hasChanges: Bool {
        if trimmedName != metric.name { return true }
        if displayedEmoji != metric.emoji { return true }
        if color.hexString != metric.colorHex { return true }
        return false
    }

    // MARK: - Save

    private func save() {
        guard isValid, hasChanges else {
            dismiss()
            return
        }
        metric.name = trimmedName
        metric.emoji = displayedEmoji
        metric.color = color
        dismiss()
    }
}

#Preview("Number") {
    let schema = MetricSchema.Fake.number(
        title: "Heart Rate",
        emoji: "❤️",
        unit: "bpm"
    )
    let metric = Metric(from: schema, color: .pink)
    return Color.clear.sheet(isPresented: .constant(true)) {
        MetricEditSheet(metric: metric)
    }
}

#Preview("Duration") {
    let schema = MetricSchema.Fake.duration(title: "Sleep", emoji: "🌙")
    let metric = Metric(from: schema, color: .indigo)
    return Color.clear.sheet(isPresented: .constant(true)) {
        MetricEditSheet(metric: metric)
    }
}




