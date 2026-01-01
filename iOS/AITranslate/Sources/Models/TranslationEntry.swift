import Foundation

/// Represents a saved translation (history or favorite)
struct TranslationEntry: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier
    let id: UUID

    /// Original source text
    let sourceText: String

    /// Translated text
    let translatedText: String

    /// Source language code
    let sourceLanguage: String

    /// Target language code
    let targetLanguage: String

    /// Detected language (if auto-detect was used)
    let detectedLanguage: String?

    /// When the translation was performed
    let createdAt: Date

    /// Whether this entry is marked as favorite
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        detectedLanguage: String? = nil,
        createdAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.detectedLanguage = detectedLanguage
        self.createdAt = createdAt
        self.isFavorite = isFavorite
    }

    /// The effective source language (detected or specified)
    var effectiveSourceLanguage: String {
        detectedLanguage ?? sourceLanguage
    }

    /// Source language display name
    var sourceLanguageDisplay: String {
        Language.find(byCode: effectiveSourceLanguage)?.shortDisplayName ?? effectiveSourceLanguage
    }

    /// Target language display name
    var targetLanguageDisplay: String {
        Language.find(byCode: targetLanguage)?.shortDisplayName ?? targetLanguage
    }

    /// Formatted creation date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Relative time description (e.g., "2 hours ago")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension TranslationEntry {
    static let preview = TranslationEntry(
        sourceText: "Hello, how are you?",
        translatedText: "Hola, ¿cómo estás?",
        sourceLanguage: "en",
        targetLanguage: "es",
        isFavorite: false
    )

    static let previewFavorite = TranslationEntry(
        sourceText: "Good morning",
        translatedText: "Buenos días",
        sourceLanguage: "en",
        targetLanguage: "es",
        isFavorite: true
    )

    static let previewList: [TranslationEntry] = [
        TranslationEntry(
            sourceText: "Hello",
            translatedText: "Hola",
            sourceLanguage: "en",
            targetLanguage: "es"
        ),
        TranslationEntry(
            sourceText: "Thank you",
            translatedText: "Merci",
            sourceLanguage: "en",
            targetLanguage: "fr",
            isFavorite: true
        ),
        TranslationEntry(
            sourceText: "Good night",
            translatedText: "Gute Nacht",
            sourceLanguage: "en",
            targetLanguage: "de"
        ),
    ]
}
#endif
