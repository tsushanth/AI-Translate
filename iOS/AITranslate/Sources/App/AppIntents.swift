import AppIntents
import SwiftUI

// MARK: - Translate Text Intent

/// Siri Shortcut: "Translate [text] to [language]"
struct TranslateTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Text"
    static var description = IntentDescription("Translate text to another language using SayIt AI")

    /// Open the app when running from Shortcuts
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Text to translate")
    var text: String

    @Parameter(title: "Target Language")
    var targetLanguage: LanguageEntity

    @Parameter(title: "Source Language", default: LanguageEntity.auto)
    var sourceLanguage: LanguageEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Translate \(\.$text) to \(\.$targetLanguage)") {
            \.$sourceLanguage
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Use the remote translation service
        let service = RemoteTranslationService()

        do {
            let result = try await service.translate(
                text: text,
                from: sourceLanguage.code,
                to: targetLanguage.code
            )

            return .result(
                value: result.translatedText,
                dialog: "Here's the translation: \(result.translatedText)"
            )
        } catch {
            throw TranslateIntentError.translationFailed(error.localizedDescription)
        }
    }
}

// MARK: - Open App Intent

/// Siri Shortcut: "Open SayIt AI"
struct OpenSayItAIIntent: AppIntent {
    static var title: LocalizedStringResource = "Open SayIt AI"
    static var description = IntentDescription("Open the SayIt AI translation app")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Open Voice Translation Intent

/// Siri Shortcut: "Start Voice Translation"
struct StartVoiceTranslationIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Voice Translation"
    static var description = IntentDescription("Open SayIt AI in voice conversation mode")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Post notification to switch to voice tab
        await MainActor.run {
            NotificationCenter.default.post(
                name: .openVoiceTranslation,
                object: nil
            )
        }
        return .result()
    }
}

// MARK: - Language Entity

/// Entity representing a language for App Intents
struct LanguageEntity: AppEntity {
    var id: String { code }
    let code: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Language"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = LanguageQuery()

    // Common languages
    static let auto = LanguageEntity(code: "auto", name: "Auto-detect")
    static let english = LanguageEntity(code: "en", name: "English")
    static let spanish = LanguageEntity(code: "es", name: "Spanish")
    static let french = LanguageEntity(code: "fr", name: "French")
    static let german = LanguageEntity(code: "de", name: "German")
    static let italian = LanguageEntity(code: "it", name: "Italian")
    static let portuguese = LanguageEntity(code: "pt", name: "Portuguese")
    static let chinese = LanguageEntity(code: "zh", name: "Chinese")
    static let japanese = LanguageEntity(code: "ja", name: "Japanese")
    static let korean = LanguageEntity(code: "ko", name: "Korean")
    static let russian = LanguageEntity(code: "ru", name: "Russian")
    static let arabic = LanguageEntity(code: "ar", name: "Arabic")
    static let hindi = LanguageEntity(code: "hi", name: "Hindi")

    static var allLanguages: [LanguageEntity] {
        [auto, english, spanish, french, german, italian, portuguese,
         chinese, japanese, korean, russian, arabic, hindi]
    }
}

// MARK: - Language Query

struct LanguageQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LanguageEntity] {
        LanguageEntity.allLanguages.filter { identifiers.contains($0.code) }
    }

    func suggestedEntities() async throws -> [LanguageEntity] {
        LanguageEntity.allLanguages
    }

    func defaultResult() async -> LanguageEntity? {
        .spanish
    }
}

// MARK: - App Shortcuts Provider

/// Provides shortcuts that appear in the Shortcuts app
struct SayItAIShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Translate with \(.applicationName)",
                "Translate \(\.$text) to \(\.$targetLanguage) with \(.applicationName)",
                "Say \(\.$text) in \(\.$targetLanguage)"
            ],
            shortTitle: "Translate Text",
            systemImageName: "character.bubble"
        )

        AppShortcut(
            intent: StartVoiceTranslationIntent(),
            phrases: [
                "Start voice translation with \(.applicationName)",
                "Voice translate with \(.applicationName)",
                "Talk to \(.applicationName)"
            ],
            shortTitle: "Voice Translation",
            systemImageName: "mic.fill"
        )

        AppShortcut(
            intent: OpenSayItAIIntent(),
            phrases: [
                "Open \(.applicationName)"
            ],
            shortTitle: "Open App",
            systemImageName: "app"
        )
    }
}

// MARK: - Intent Errors

enum TranslateIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case translationFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let openVoiceTranslation = Notification.Name("openVoiceTranslation")
}
