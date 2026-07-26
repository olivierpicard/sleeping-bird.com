//
//  EmojiInputField.swift
//  ArperBird
//

import SwiftUI

/// A tappable field that brings up the system emoji keyboard and stores a
/// single emoji grapheme. Shared by the metric edit sheet and the editable
/// tracker header.
struct EmojiInputField: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 34

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.delegate = context.coordinator
        field.textAlignment = .center
        field.font = .systemFont(ofSize: fontSize)
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
        if uiView.font?.pointSize != fontSize {
            uiView.font = .systemFont(ofSize: fontSize)
        }
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

final class EmojiTextField: UITextField {
    override var textInputContextIdentifier: String? { "" }
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
            ?? super.textInputMode
    }
}

extension String {
    var isSingleEmoji: Bool {
        guard count == 1, let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation
            || unicodeScalars.contains { $0.properties.isEmojiPresentation }
            || unicodeScalars.contains { $0.properties.isEmoji && $0.value >= 0x203C }
    }
}
