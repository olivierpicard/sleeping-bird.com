//
//  MetricEditSheet.swift
//  SleepingBird
//

import SwiftUI

struct MetricEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var metric: Metric

    @State private var name: String
    @State private var unit: String
    @State private var emoji: String
    @State private var color: Color
    @FocusState private var focused: Field?

    private let supportsUnit: Bool

    enum Field { case name, unit }

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
        if case .number(let cfg) = metric.config {
            _unit = State(initialValue: cfg.unit ?? "")
            self.supportsUnit = true
        } else {
            _unit = State(initialValue: "")
            self.supportsUnit = false
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
                if supportsUnit {
                    Text(unit.isEmpty ? "No unit" : unit)
                        .font(.subheadline)
                        .foregroundStyle(unit.isEmpty ? .secondary : color)
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
        VStack(spacing: 0) {
            fieldRow(
                label: "NAME",
                placeholder: "Metric name",
                text: $name,
                field: .name,
                submitLabel: supportsUnit ? .next : .done,
                autocapitalization: .sentences,
                onSubmit: {
                    if supportsUnit { focused = .unit } else { save() }
                }
            )

            if supportsUnit {
                Divider().padding(.leading, 16)
                fieldRow(
                    label: "UNIT",
                    placeholder: "e.g. kg, steps, kcal",
                    text: $unit,
                    field: .unit,
                    submitLabel: .done,
                    autocapitalization: .never,
                    onSubmit: save
                )
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func fieldRow(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        submitLabel: SubmitLabel,
        autocapitalization: TextInputAutocapitalization,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .font(.body)
                .textFieldStyle(.plain)
                .focused($focused, equals: field)
                .submitLabel(submitLabel)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(field == .unit)
                .onSubmit(onSubmit)
                .tint(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var trimmedUnit: String {
        unit.trimmingCharacters(in: .whitespacesAndNewlines)
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
        if supportsUnit, case .number(let cfg) = metric.config {
            if trimmedUnit != (cfg.unit ?? "") { return true }
        }
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
        if supportsUnit, case .number(let cfg) = metric.config {
            metric.config = .number(
                NumberConfig(
                    min: cfg.min,
                    max: cfg.max,
                    granularity: cfg.granularity,
                    unit: trimmedUnit.isEmpty ? nil : trimmedUnit,
                    goal: cfg.goal,
                    behavior: cfg.behavior
                )
            )
        }
        dismiss()
    }
}

// MARK: - Emoji input field

/// A circular tappable field that brings up the system emoji keyboard
/// and stores a single emoji grapheme.
private struct EmojiInputField: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.delegate = context.coordinator
        field.textAlignment = .center
        field.font = .systemFont(ofSize: 34)
        field.tintColor = .clear
        field.autocorrectionType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.spellCheckingType = .no
        field.text = text
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ uiView: EmojiTextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        @objc func editingChanged(_ sender: UITextField) {
            let raw = sender.text ?? ""
            let sanitized = Self.lastEmoji(in: raw) ?? text
            if sender.text != sanitized { sender.text = sanitized }
            if text != sanitized { text = sanitized }
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            if string.isEmpty { return true }
            return Self.lastEmoji(in: string) != nil
        }

        private static func lastEmoji(in input: String) -> String? {
            for char in input.reversed() where String(char).isSingleEmoji {
                return String(char)
            }
            return nil
        }
    }
}

private final class EmojiTextField: UITextField {
    override var textInputContextIdentifier: String? { "" }
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
            ?? super.textInputMode
    }
}

private extension String {
    var isSingleEmoji: Bool {
        guard count == 1, let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation
            || unicodeScalars.contains { $0.properties.isEmojiPresentation }
            || unicodeScalars.contains { $0.properties.isEmoji && $0.value >= 0x203C }
    }
}

#if DEBUG
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
#endif
