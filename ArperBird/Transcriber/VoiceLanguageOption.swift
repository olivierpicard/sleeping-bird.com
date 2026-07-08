//
//  VoiceLanguageOption.swift
//  ArperBird
//
//  Created by Olivier Picard on 29/05/2026.
//

import Foundation

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
