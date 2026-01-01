import Foundation

/// Represents a supported language for translation
struct Language: Identifiable, Hashable, Codable, Sendable {
    /// ISO 639-1 language code
    let code: String

    /// English display name
    let name: String

    /// Native display name
    let nativeName: String

    /// Whether the language uses RTL script
    let isRTL: Bool

    var id: String { code }

    /// Display name showing both English and native name
    var displayName: String {
        if name == nativeName {
            return name
        }
        return "\(name) (\(nativeName))"
    }

    /// Short display for compact UI
    var shortDisplayName: String {
        name
    }

    /// Flag emoji for the language's primary country
    var flagEmoji: String {
        switch code {
        case "en": return "🇺🇸"
        case "es": return "🇪🇸"
        case "fr": return "🇫🇷"
        case "de": return "🇩🇪"
        case "it": return "🇮🇹"
        case "pt": return "🇧🇷"
        case "ru": return "🇷🇺"
        case "zh": return "🇨🇳"
        case "ja": return "🇯🇵"
        case "ko": return "🇰🇷"
        case "ar": return "🇸🇦"
        case "hi": return "🇮🇳"
        case "nl": return "🇳🇱"
        case "pl": return "🇵🇱"
        case "tr": return "🇹🇷"
        case "vi": return "🇻🇳"
        case "th": return "🇹🇭"
        case "sv": return "🇸🇪"
        case "da": return "🇩🇰"
        case "fi": return "🇫🇮"
        case "no": return "🇳🇴"
        case "cs": return "🇨🇿"
        case "el": return "🇬🇷"
        case "he": return "🇮🇱"
        case "id": return "🇮🇩"
        case "ms": return "🇲🇾"
        case "ro": return "🇷🇴"
        case "uk": return "🇺🇦"
        case "hu": return "🇭🇺"
        case "bn": return "🇧🇩"
        case "auto": return "🌐"
        default: return "🌐"
        }
    }
}

// MARK: - Auto-Detect Option

extension Language {
    /// Special "auto-detect" option for source language
    static let autoDetect = Language(
        code: "auto",
        name: "Detect Language",
        nativeName: "Detect Language",
        isRTL: false
    )
}

// MARK: - Supported Languages

extension Language {

    /// All supported languages for translation
    static let supportedLanguages: [Language] = [
        Language(code: "en", name: "English", nativeName: "English", isRTL: false),
        Language(code: "es", name: "Spanish", nativeName: "Español", isRTL: false),
        Language(code: "fr", name: "French", nativeName: "Français", isRTL: false),
        Language(code: "de", name: "German", nativeName: "Deutsch", isRTL: false),
        Language(code: "it", name: "Italian", nativeName: "Italiano", isRTL: false),
        Language(code: "pt", name: "Portuguese", nativeName: "Português", isRTL: false),
        Language(code: "ru", name: "Russian", nativeName: "Русский", isRTL: false),
        Language(code: "zh", name: "Chinese", nativeName: "中文", isRTL: false),
        Language(code: "ja", name: "Japanese", nativeName: "日本語", isRTL: false),
        Language(code: "ko", name: "Korean", nativeName: "한국어", isRTL: false),
        Language(code: "ar", name: "Arabic", nativeName: "العربية", isRTL: true),
        Language(code: "hi", name: "Hindi", nativeName: "हिन्दी", isRTL: false),
        Language(code: "nl", name: "Dutch", nativeName: "Nederlands", isRTL: false),
        Language(code: "pl", name: "Polish", nativeName: "Polski", isRTL: false),
        Language(code: "tr", name: "Turkish", nativeName: "Türkçe", isRTL: false),
        Language(code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", isRTL: false),
        Language(code: "th", name: "Thai", nativeName: "ไทย", isRTL: false),
        Language(code: "sv", name: "Swedish", nativeName: "Svenska", isRTL: false),
        Language(code: "da", name: "Danish", nativeName: "Dansk", isRTL: false),
        Language(code: "fi", name: "Finnish", nativeName: "Suomi", isRTL: false),
        Language(code: "no", name: "Norwegian", nativeName: "Norsk", isRTL: false),
        Language(code: "cs", name: "Czech", nativeName: "Čeština", isRTL: false),
        Language(code: "el", name: "Greek", nativeName: "Ελληνικά", isRTL: false),
        Language(code: "he", name: "Hebrew", nativeName: "עברית", isRTL: true),
        Language(code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", isRTL: false),
        Language(code: "ms", name: "Malay", nativeName: "Bahasa Melayu", isRTL: false),
        Language(code: "ro", name: "Romanian", nativeName: "Română", isRTL: false),
        Language(code: "uk", name: "Ukrainian", nativeName: "Українська", isRTL: false),
        Language(code: "hu", name: "Hungarian", nativeName: "Magyar", isRTL: false),
        Language(code: "bn", name: "Bengali", nativeName: "বাংলা", isRTL: false),
    ].sorted { $0.name < $1.name }

    /// Languages available for source selection (includes auto-detect)
    static var sourceLanguages: [Language] {
        [.autoDetect] + supportedLanguages
    }

    /// Languages available for target selection
    static var targetLanguages: [Language] {
        supportedLanguages
    }

    /// Find a language by its code
    static func find(byCode code: String) -> Language? {
        if code == "auto" { return .autoDetect }
        return supportedLanguages.first { $0.code == code }
    }

    /// BCP-47 locale code for speech services
    /// Maps ISO 639-1 codes to full locale codes
    var speechLocaleCode: String {
        switch code {
        case "en": return "en-US"
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "it": return "it-IT"
        case "pt": return "pt-BR"
        case "ru": return "ru-RU"
        case "zh": return "zh-CN"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "ar": return "ar-SA"
        case "hi": return "hi-IN"
        case "nl": return "nl-NL"
        case "pl": return "pl-PL"
        case "tr": return "tr-TR"
        case "vi": return "vi-VN"
        case "th": return "th-TH"
        case "sv": return "sv-SE"
        case "da": return "da-DK"
        case "fi": return "fi-FI"
        case "no": return "nb-NO"
        case "cs": return "cs-CZ"
        case "el": return "el-GR"
        case "he": return "he-IL"
        case "id": return "id-ID"
        case "ms": return "ms-MY"
        case "ro": return "ro-RO"
        case "uk": return "uk-UA"
        case "hu": return "hu-HU"
        case "bn": return "bn-IN"
        default: return code
        }
    }
}
