//
//  VoiceLanguage.swift
//  SleepingBird
//
//  Created by Olivier Picard on 29/05/2026.
//

import PostHog
import SwiftUI
import UIKit

struct VoiceLanguageConfigView: View {

    /// Invoked when the user taps "Next" to advance the onboarding flow.
    var onContinue: () -> Void = {}

    /// Multiplier applied to the hero mic's dimensions (rings, fill, icons).
    /// `1` is the original size; values below shrink it proportionally.
    var heroScale: CGFloat = 0.8

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
        VStack(alignment: .center, spacing: 0) {
            micHero
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

            Spacer(minLength: 0)

            titleBlock

            languageSelector
                .padding(.top, 24)
                .padding(.bottom, 34)

            Spacer(minLength: 0)

            continueButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            EmptyDashboardBackground(intensity: 0.3)
                .ignoresSafeArea()
        }
        .trackScreen("Onboarding_Language")
    }

    // MARK: - Progress

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

    //  MARK: - Hero

    private var isDark: Bool { colorScheme == .dark }

    private var micHero: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    accent.opacity(isDark ? 0.30 : 0.12),
                    lineWidth: isDark ? 1.5 : 1
                )
                .frame(width: 300 * heroScale, height: 300 * heroScale)
            Circle()
                .strokeBorder(
                    accent.opacity(isDark ? 0.45 : 0.18),
                    lineWidth: isDark ? 1.5 : 1
                )
                .frame(width: 220 * heroScale, height: 220 * heroScale)
            Circle()
                .fill(accent.opacity(isDark ? 0.28 : 0.12))
                .frame(width: 132 * heroScale, height: 132 * heroScale)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "globe")
                        .font(.system(size: 22 * heroScale, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40 * heroScale, height: 40 * heroScale)
                        .background(Circle().fill(accent))
                        .background(
                            Circle()
                                .fill(Color(uiColor: .systemBackground))
                                .padding(-3 * heroScale)
                        )
                        .offset(x: 6 * heroScale, y: 6 * heroScale)
                }
            Image(systemName: "mic.fill")
                .font(.system(size: 48 * heroScale))
                .foregroundStyle(accent)
        }
        .accessibilityHidden(true)

    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Help us understand you better")
                .font(.system(size: 36, weight: .heavy))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                "We'll use your language to understand your voice more accurately."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Selector

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
                .accessibilityHidden(true)

            if showRegionInline {
                HStack(spacing: 8) {
                    Text(option.language)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let region = option.region {
                        Text(region)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.language)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let region = option.region {
                        Text(region)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(option.accessibilityLabel)
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button(action: { onContinue() }) {
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
                    PostHogSDK.shared.capture(
                        "dictation_language_changed",
                        properties: ["language_code": option.id]
                    )
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text(option.flag)
                            .font(.title)
                            .frame(width: 34)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.language)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let region = option.region {
                                Text(region)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer(minLength: 0)

                        if option == selection {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(option.accessibilityLabel)
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
        .trackScreen("Onboarding_VoiceLanguage")
    }
}

// MARK: - Model

struct VoiceLanguageOption: Identifiable, Equatable {
    let id: String
    let flag: String

    /// Locale built from this option's own identifier. Localizing *through this*
    /// yields endonyms — each name rendered in its own language/script.
    private var locale: Locale { Locale(identifier: id) }

    /// Language name in its own language: "English", "Français", "日本語", "العربية".
    var language: String {
        let code = locale.language.languageCode?.identifier ?? id
        return locale.localizedString(forLanguageCode: code) ?? code
    }

    /// Region name in its own language, or `nil` when the id carries no region.
    /// "en-GB" → "United Kingdom", "es-419" → "Latinoamérica", "en"/"ar" → nil.
    var region: String? {
        guard let code = locale.region?.identifier else { return nil }
        return locale.localizedString(forRegionCode: code)
    }

    /// VoiceOver label combining language and region (the flag is read poorly,
    /// so it's hidden in the UI). e.g. "English, United Kingdom" or "العربية".
    var accessibilityLabel: String {
        guard let region else { return language }
        return "\(language), \(region)"
    }

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

    /// All options, ordered by their endonym (each language's own name).
    static let all: [VoiceLanguageOption] = catalog.sorted {
        $0.language.localizedStandardCompare($1.language) == .orderedAscending
    }

    // Display names are derived from `id` at render time (endonyms); only the
    // flag is curated here, since it isn't reliably derivable from a locale.
    // Source order is grouped by English name for maintenance; `all` re-sorts
    // by endonym for display.
    private static let catalog: [VoiceLanguageOption] = [
        // Arabic
        .init(id: "ar", flag: "🇸🇦"),
        .init(id: "ar-EG", flag: "🇪🇬"),
        .init(id: "ar-SA", flag: "🇸🇦"),
        .init(id: "ar-AE", flag: "🇦🇪"),
        .init(id: "ar-IQ", flag: "🇮🇶"),
        .init(id: "ar-LB", flag: "🇱🇧"),
        .init(id: "ar-MA", flag: "🇲🇦"),
        .init(id: "ar-SD", flag: "🇸🇩"),

        // Belarusian
        .init(id: "be", flag: "🇧🇾"),

        // Bengali
        .init(id: "bn", flag: "🇧🇩"),

        // Bosnian
        .init(id: "bs", flag: "🇧🇦"),

        // Bulgarian
        .init(id: "bg", flag: "🇧🇬"),

        // Catalan
        .init(id: "ca", flag: "🇪🇸"),

        // Chinese
        .init(id: "zh", flag: "🇨🇳"),
        .init(id: "zh-TW", flag: "🇹🇼"),
        .init(id: "zh-HK", flag: "🇭🇰"),

        // Croatian
        .init(id: "hr", flag: "🇭🇷"),

        // Czech
        .init(id: "cs", flag: "🇨🇿"),

        // Danish
        .init(id: "da", flag: "🇩🇰"),

        // Dutch
        .init(id: "nl", flag: "🇳🇱"),

        // English
        .init(id: "en", flag: "🇺🇸"),
        .init(id: "en-AU", flag: "🇦🇺"),
        .init(id: "en-GB", flag: "🇬🇧"),
        .init(id: "en-IN", flag: "🇮🇳"),
        .init(id: "en-NZ", flag: "🇳🇿"),

        // Estonian
        .init(id: "et", flag: "🇪🇪"),

        // Finnish
        .init(id: "fi", flag: "🇫🇮"),

        // Flemish
        .init(id: "nl-BE", flag: "🇧🇪"),

        // French
        .init(id: "fr", flag: "🇫🇷"),
        .init(id: "fr-CA", flag: "🇨🇦"),

        // German
        .init(id: "de", flag: "🇩🇪"),
        .init(id: "de-CH", flag: "🇨🇭"),

        // Greek
        .init(id: "el", flag: "🇬🇷"),

        // Gujarati
        .init(id: "gu", flag: "🇮🇳"),

        // Hebrew
        .init(id: "he", flag: "🇮🇱"),

        // Hindi
        .init(id: "hi", flag: "🇮🇳"),

        // Hungarian
        .init(id: "hu", flag: "🇭🇺"),

        // Indonesian
        .init(id: "id", flag: "🇮🇩"),

        // Italian
        .init(id: "it", flag: "🇮🇹"),

        // Japanese
        .init(id: "ja", flag: "🇯🇵"),

        // Kannada
        .init(id: "kn", flag: "🇮🇳"),

        // Korean
        .init(id: "ko", flag: "🇰🇷"),

        // Latvian
        .init(id: "lv", flag: "🇱🇻"),

        // Lithuanian
        .init(id: "lt", flag: "🇱🇹"),

        // Macedonian
        .init(id: "mk", flag: "🇲🇰"),

        // Malay
        .init(id: "ms", flag: "🇲🇾"),

        // Marathi
        .init(id: "mr", flag: "🇮🇳"),

        // Norwegian
        .init(id: "no", flag: "🇳🇴"),

        // Persian
        .init(id: "fa", flag: "🇮🇷"),

        // Polish
        .init(id: "pl", flag: "🇵🇱"),

        // Portuguese
        .init(id: "pt", flag: "🇵🇹"),
        .init(id: "pt-BR", flag: "🇧🇷"),

        // Romanian
        .init(id: "ro", flag: "🇷🇴"),

        // Russian
        .init(id: "ru", flag: "🇷🇺"),

        // Serbian
        .init(id: "sr", flag: "🇷🇸"),

        // Slovak
        .init(id: "sk", flag: "🇸🇰"),

        // Slovenian
        .init(id: "sl", flag: "🇸🇮"),

        // Spanish
        .init(id: "es", flag: "🇪🇸"),
        .init(id: "es-419", flag: "🌎"),

        // Swedish
        .init(id: "sv", flag: "🇸🇪"),

        // Tagalog
        .init(id: "tl", flag: "🇵🇭"),

        // Tamil
        .init(id: "ta", flag: "🇮🇳"),

        // Telugu
        .init(id: "te", flag: "🇮🇳"),

        // Thai
        .init(id: "th", flag: "🇹🇭"),

        // Turkish
        .init(id: "tr", flag: "🇹🇷"),

        // Ukrainian
        .init(id: "uk", flag: "🇺🇦"),

        // Urdu
        .init(id: "ur", flag: "🇵🇰"),

        // Vietnamese
        .init(id: "vi", flag: "🇻🇳"),
    ]
}

#Preview {
    VoiceLanguageConfigView()
}
