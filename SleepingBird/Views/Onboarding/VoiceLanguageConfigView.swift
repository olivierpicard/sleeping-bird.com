//
//  VoiceLanguage.swift
//  SleepingBird
//
//  Created by Olivier Picard on 29/05/2026.
//

import SwiftUI
import UIKit

struct VoiceLanguageConfigView: View {
    var onBack: () -> Void = {}
    var onContinue: (VoiceLanguageOption) -> Void = { _ in }

    @AppStorage(VoiceLanguageOption.storageKey)
    private var storedLanguageID = VoiceLanguageOption.default.id
    @State private var isPickerPresented = false

    /// The currently selected option, resolved from the persisted id.
    private var selection: VoiceLanguageOption {
        VoiceLanguageOption.all.first { $0.id == storedLanguageID } ?? .default
    }

    /// Bridges the persisted id to the picker's `VoiceLanguageOption` binding.
    private var selectionBinding: Binding<VoiceLanguageOption> {
        Binding(
            get: { selection },
            set: { storedLanguageID = $0.id }
        )
    }

    @Environment(\.colorScheme) private var colorScheme

    private let accent = Color.indigo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            progressBar
                .padding(.top, 8)

            backButton
                .padding(.top, 20)

            micHero
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 32)

            titleBlock

            languageSelector
                .padding(.top, 28)

            Spacer(minLength: 24)

            continueButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Progress

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < 2 ? accent : Color(uiColor: .systemGray5))
                    .frame(height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step 2 of 4")
    }

    // MARK: Back

    private var backButton: some View {
        Button(action: onBack) {
            Label("Back", systemImage: "chevron.left")
                .labelStyle(.iconOnly)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle().strokeBorder(
                        Color(uiColor: .systemGray4),
                        lineWidth: 1
                    )
                )
        }
    }

    // MARK: Hero

    private var isDark: Bool { colorScheme == .dark }

    private var micHero: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    accent.opacity(isDark ? 0.30 : 0.12),
                    lineWidth: isDark ? 1.5 : 1
                )
                .frame(width: 220, height: 220)
            Circle()
                .strokeBorder(
                    accent.opacity(isDark ? 0.45 : 0.18),
                    lineWidth: isDark ? 1.5 : 1
                )
                .frame(width: 160, height: 160)
            Circle()
                .fill(accent.opacity(isDark ? 0.28 : 0.12))
                .frame(width: 96, height: 96)
            Image(systemName: "mic.fill")
                .font(.system(size: 34))
                .foregroundStyle(accent)
        }
        .accessibilityHidden(true)
    }

    // MARK: Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your language")
                .font(.system(size: 36, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)

            Text("We use this to transcribe your voice metrics accurately.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Selector

    private var languageSelector: some View {
        Button {
            isPickerPresented = true
        } label: {
            row(for: selection, showRegionInline: false)
                .overlay(alignment: .trailing) {
                    Text("Change")
                        .padding(.horizontal)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(accent)
                }
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(uiColor: .systemGray4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $isPickerPresented) {
            VoiceLanguagePicker(selection: selectionBinding, accent: accent)
        }
    }

    private func row(for option: VoiceLanguageOption, showRegionInline: Bool)
        -> some View
    {
        HStack(spacing: 14) {
            Text(option.flag)
                .font(.title)
                .frame(width: 34)

            if showRegionInline {
                HStack(spacing: 8) {
                    Text(option.language)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(option.region)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.language)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(option.region)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: Continue

    private var continueButton: some View {
        Button(action: { onContinue(selection) }) {
            // Distinct key: the shared "Continue" key is mapped to "Subscribe" by the paywall.
            Text("Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
        }
        .controlSize(.extraLarge)
        .buttonStyle(.glassProminent)
        .tint(accent)
    }
}

// MARK: - Picker Sheet

private struct VoiceLanguagePicker: View {
    @Binding var selection: VoiceLanguageOption
    let accent: Color

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(VoiceLanguageOption.all) { option in
                Button {
                    selection = option
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text(option.flag)
                            .font(.title)
                            .frame(width: 34)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.language)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(option.region)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        if option == selection {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(
                    EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
                )
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Language & Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }
}

// MARK: - Model

struct VoiceLanguageOption: Identifiable, Equatable {
    let id: String
    let flag: String
    let language: String
    let region: String

    /// `UserDefaults`/`@AppStorage` key under which the chosen id is persisted.
    static let storageKey = "voiceLanguage"

    /// Initial selection shown before the user picks a language.
    static let `default`: VoiceLanguageOption =
        all.first { $0.id == "en" } ?? all[0]

    /// The persisted selection, for use anywhere outside the onboarding view
    /// (e.g. configuring the transcriber). Falls back to `.default`.
    static var saved: VoiceLanguageOption {
        let id = UserDefaults.standard.string(forKey: storageKey)
        return all.first { $0.id == id } ?? .default
    }

    static let all: [VoiceLanguageOption] = [
        // Arabic
        .init(
            id: "ar",
            flag: "🇸🇦",
            language: "Arabic",
            region: "Modern Standard"
        ),
        .init(id: "ar-EG", flag: "🇪🇬", language: "Arabic", region: "Egypt"),
        .init(
            id: "ar-SA",
            flag: "🇸🇦",
            language: "Arabic",
            region: "Saudi Arabia"
        ),
        .init(
            id: "ar-AE",
            flag: "🇦🇪",
            language: "Arabic",
            region: "United Arab Emirates"
        ),
        .init(id: "ar-IQ", flag: "🇮🇶", language: "Arabic", region: "Iraq"),
        .init(
            id: "ar-LB",
            flag: "🇱🇧",
            language: "Arabic",
            region: "Lebanon (Levantine)"
        ),
        .init(
            id: "ar-MA",
            flag: "🇲🇦",
            language: "Arabic",
            region: "Morocco (Maghrebi)"
        ),
        .init(id: "ar-SD", flag: "🇸🇩", language: "Arabic", region: "Sudan"),

        // Belarusian
        .init(id: "be", flag: "🇧🇾", language: "Belarusian", region: "Belarus"),

        // Bengali
        .init(id: "bn", flag: "🇧🇩", language: "Bengali", region: "Bangladesh"),

        // Bosnian
        .init(
            id: "bs",
            flag: "🇧🇦",
            language: "Bosnian",
            region: "Bosnia & Herzegovina"
        ),

        // Bulgarian
        .init(id: "bg", flag: "🇧🇬", language: "Bulgarian", region: "Bulgaria"),

        // Catalan
        .init(id: "ca", flag: "🇪🇸", language: "Catalan", region: "Catalonia"),

        // Chinese
        .init(
            id: "zh",
            flag: "🇨🇳",
            language: "Chinese",
            region: "Mandarin, Simplified"
        ),
        .init(
            id: "zh-TW",
            flag: "🇹🇼",
            language: "Chinese",
            region: "Mandarin, Traditional"
        ),
        .init(
            id: "zh-HK",
            flag: "🇭🇰",
            language: "Cantonese",
            region: "Hong Kong"
        ),

        // Croatian
        .init(id: "hr", flag: "🇭🇷", language: "Croatian", region: "Croatia"),

        // Czech
        .init(id: "cs", flag: "🇨🇿", language: "Czech", region: "Czechia"),

        // Danish
        .init(id: "da", flag: "🇩🇰", language: "Danish", region: "Denmark"),

        // Dutch
        .init(id: "nl", flag: "🇳🇱", language: "Dutch", region: "Netherlands"),

        // English
        .init(
            id: "en",
            flag: "🇺🇸",
            language: "English",
            region: "United States"
        ),
        .init(id: "en-AU", flag: "🇦🇺", language: "English", region: "Australia"),
        .init(
            id: "en-GB",
            flag: "🇬🇧",
            language: "English",
            region: "United Kingdom"
        ),
        .init(id: "en-IN", flag: "🇮🇳", language: "English", region: "India"),
        .init(
            id: "en-NZ",
            flag: "🇳🇿",
            language: "English",
            region: "New Zealand"
        ),

        // Estonian
        .init(id: "et", flag: "🇪🇪", language: "Estonian", region: "Estonia"),

        // Finnish
        .init(id: "fi", flag: "🇫🇮", language: "Finnish", region: "Finland"),

        // Flemish
        .init(id: "nl-BE", flag: "🇧🇪", language: "Flemish", region: "Belgium"),

        // French
        .init(id: "fr", flag: "🇫🇷", language: "French", region: "France"),
        .init(id: "fr-CA", flag: "🇨🇦", language: "French", region: "Canada"),

        // German
        .init(id: "de", flag: "🇩🇪", language: "German", region: "Germany"),
        .init(
            id: "de-CH",
            flag: "🇨🇭",
            language: "German",
            region: "Switzerland"
        ),

        // Greek
        .init(id: "el", flag: "🇬🇷", language: "Greek", region: "Greece"),

        // Gujarati
        .init(id: "gu", flag: "🇮🇳", language: "Gujarati", region: "India"),

        // Hebrew
        .init(id: "he", flag: "🇮🇱", language: "Hebrew", region: "Israel"),

        // Hindi
        .init(id: "hi", flag: "🇮🇳", language: "Hindi", region: "India"),

        // Hungarian
        .init(id: "hu", flag: "🇭🇺", language: "Hungarian", region: "Hungary"),

        // Indonesian
        .init(id: "id", flag: "🇮🇩", language: "Indonesian", region: "Indonesia"),

        // Italian
        .init(id: "it", flag: "🇮🇹", language: "Italian", region: "Italy"),

        // Japanese
        .init(id: "ja", flag: "🇯🇵", language: "Japanese", region: "Japan"),

        // Kannada
        .init(id: "kn", flag: "🇮🇳", language: "Kannada", region: "India"),

        // Korean
        .init(id: "ko", flag: "🇰🇷", language: "Korean", region: "South Korea"),

        // Latvian
        .init(id: "lv", flag: "🇱🇻", language: "Latvian", region: "Latvia"),

        // Lithuanian
        .init(id: "lt", flag: "🇱🇹", language: "Lithuanian", region: "Lithuania"),

        // Macedonian
        .init(
            id: "mk",
            flag: "🇲🇰",
            language: "Macedonian",
            region: "North Macedonia"
        ),

        // Malay
        .init(id: "ms", flag: "🇲🇾", language: "Malay", region: "Malaysia"),

        // Marathi
        .init(id: "mr", flag: "🇮🇳", language: "Marathi", region: "India"),

        // Norwegian
        .init(id: "no", flag: "🇳🇴", language: "Norwegian", region: "Norway"),

        // Persian
        .init(id: "fa", flag: "🇮🇷", language: "Persian", region: "Iran"),

        // Polish
        .init(id: "pl", flag: "🇵🇱", language: "Polish", region: "Poland"),

        // Portuguese
        .init(id: "pt", flag: "🇵🇹", language: "Portuguese", region: "Portugal"),
        .init(id: "pt-BR", flag: "🇧🇷", language: "Portuguese", region: "Brazil"),

        // Romanian
        .init(id: "ro", flag: "🇷🇴", language: "Romanian", region: "Romania"),

        // Russian
        .init(id: "ru", flag: "🇷🇺", language: "Russian", region: "Russia"),

        // Serbian
        .init(id: "sr", flag: "🇷🇸", language: "Serbian", region: "Serbia"),

        // Slovak
        .init(id: "sk", flag: "🇸🇰", language: "Slovak", region: "Slovakia"),

        // Slovenian
        .init(id: "sl", flag: "🇸🇮", language: "Slovenian", region: "Slovenia"),

        // Spanish
        .init(id: "es", flag: "🇪🇸", language: "Spanish", region: "Spain"),
        .init(
            id: "es-419",
            flag: "🌎",
            language: "Spanish",
            region: "Latin America"
        ),

        // Swedish
        .init(id: "sv", flag: "🇸🇪", language: "Swedish", region: "Sweden"),

        // Tagalog
        .init(id: "tl", flag: "🇵🇭", language: "Tagalog", region: "Philippines"),

        // Tamil
        .init(id: "ta", flag: "🇮🇳", language: "Tamil", region: "India"),

        // Telugu
        .init(id: "te", flag: "🇮🇳", language: "Telugu", region: "India"),

        // Thai
        .init(id: "th", flag: "🇹🇭", language: "Thai", region: "Thailand"),

        // Turkish
        .init(id: "tr", flag: "🇹🇷", language: "Turkish", region: "Turkey"),

        // Ukrainian
        .init(id: "uk", flag: "🇺🇦", language: "Ukrainian", region: "Ukraine"),

        // Urdu
        .init(id: "ur", flag: "🇵🇰", language: "Urdu", region: "Pakistan"),

        // Vietnamese
        .init(id: "vi", flag: "🇻🇳", language: "Vietnamese", region: "Vietnam"),
    ]
}

#Preview {
    VoiceLanguageConfigView()
}
