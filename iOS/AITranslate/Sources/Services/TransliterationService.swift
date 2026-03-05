import Foundation

/// Service for converting non-Latin scripts to romanized (Latin) text
/// Examples: 你好 → Nǐ hǎo, こんにちは → Konnichiwa, مرحبا → Marhaba
final class TransliterationService {

    static let shared = TransliterationService()

    private init() {}

    // MARK: - Languages that need transliteration

    /// Language codes that use non-Latin scripts
    private let nonLatinLanguages: Set<String> = [
        "zh", "ja", "ko", "ar", "hi", "ru", "th", "he", "fa", "ur",
        "bn", "ta", "te", "ml", "kn", "gu", "pa", "mr", "ne",
        "el", "uk", "bg", "sr", "mk", "ka", "am", "my", "km", "lo"
    ]

    /// Check if a language uses non-Latin script
    func needsTransliteration(languageCode: String) -> Bool {
        let baseCode = String(languageCode.prefix(2))
        return nonLatinLanguages.contains(baseCode)
    }

    // MARK: - Transliteration

    /// Transliterates text to Latin characters using iOS built-in APIs
    /// - Parameters:
    ///   - text: The text to transliterate
    ///   - languageCode: The source language code
    /// - Returns: Romanized text, or nil if no transliteration is needed/available
    func transliterate(_ text: String, languageCode: String) -> String? {
        guard needsTransliteration(languageCode: languageCode) else {
            return nil
        }

        // Use CFStringTransform for transliteration
        let mutableString = NSMutableString(string: text)

        // Try language-specific transliteration first
        if let transform = languageSpecificTransform(for: languageCode) {
            if CFStringTransform(mutableString, nil, transform as CFString, false) {
                return cleanupTransliteration(mutableString as String)
            }
        }

        // Fallback to general Latin transliteration
        if CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false) {
            // Also strip diacritics for cleaner output (optional)
            // CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
            return cleanupTransliteration(mutableString as String)
        }

        return nil
    }

    /// Returns language-specific transform identifier
    private func languageSpecificTransform(for languageCode: String) -> String? {
        let baseCode = String(languageCode.prefix(2))

        switch baseCode {
        case "zh":
            return "Hans-Latin" // Simplified Chinese to Pinyin
        case "ja":
            return "Hiragana-Latin" // Japanese to Romaji
        case "ko":
            return "Hangul-Latin" // Korean to Romanization
        case "ar":
            return "Arabic-Latin" // Arabic to Latin
        case "ru", "uk", "bg", "sr", "mk":
            return "Cyrillic-Latin" // Cyrillic scripts
        case "el":
            return "Greek-Latin"
        case "he":
            return "Hebrew-Latin"
        case "th":
            return "Thai-Latin"
        case "hi", "mr", "ne":
            return "Devanagari-Latin"
        case "bn":
            return "Bengali-Latin"
        case "ta":
            return "Tamil-Latin"
        case "te":
            return "Telugu-Latin"
        case "ml":
            return "Malayalam-Latin"
        case "kn":
            return "Kannada-Latin"
        case "gu":
            return "Gujarati-Latin"
        case "pa":
            return "Gurmukhi-Latin"
        case "ka":
            return "Georgian-Latin"
        case "am":
            return "Ethiopic-Latin"
        case "my":
            return "Myanmar-Latin"
        case "km":
            return "Khmer-Latin"
        default:
            return nil
        }
    }

    /// Clean up the transliterated output
    private func cleanupTransliteration(_ text: String) -> String {
        // Remove extra whitespace
        let cleaned = text
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return cleaned.isEmpty ? text : cleaned
    }

    // MARK: - Formatting

    /// Formats the transliteration for display (e.g., in parentheses or italics)
    func formatForDisplay(_ transliteration: String) -> String {
        return "(\(transliteration))"
    }
}

// MARK: - String Extension

extension String {
    /// Returns transliterated version if the text contains non-Latin characters
    var transliterated: String? {
        // Quick check if text contains non-ASCII characters
        guard self.unicodeScalars.contains(where: { !$0.isASCII }) else {
            return nil
        }

        let mutableString = NSMutableString(string: self)
        if CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false) {
            let result = mutableString as String
            // Only return if it's different from original
            return result != self ? result : nil
        }
        return nil
    }
}
