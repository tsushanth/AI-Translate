import Foundation
import SwiftUI
import Combine

/// ViewModel for the Phrasebook feature
@MainActor
final class PhrasebookViewModel: ObservableObject {

    // MARK: - Published State

    /// Search query for filtering phrases
    @Published var searchQuery: String = ""

    /// Currently selected target language for translation
    @Published var targetLanguage: Language = Language.supportedLanguages.first { $0.code == "es" }
        ?? Language.supportedLanguages[0]

    /// Current translation result (after tapping a phrase)
    @Published private(set) var currentTranslation: PhraseTranslation?

    /// Whether a translation is in progress
    @Published private(set) var isTranslating: Bool = false

    /// Error message if translation fails
    @Published var errorMessage: String?

    /// Whether to show error alert
    @Published var showError: Bool = false

    /// Show language picker sheet
    @Published var showLanguagePicker: Bool = false

    // MARK: - Dependencies

    private let translationService: TranslationService
    private let textToSpeechService: TextToSpeechService

    // MARK: - Private State

    private var translationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        translationService: TranslationService = RemoteTranslationService(),
        textToSpeechService: TextToSpeechService = TextToSpeechService()
    ) {
        self.translationService = translationService
        self.textToSpeechService = textToSpeechService
    }

    // MARK: - Computed Properties

    /// All available categories
    var categories: [PhraseCategory] {
        PhrasebookData.categories
    }

    /// Search results across all categories
    var searchResults: [(category: PhraseCategory, phrase: Phrase)] {
        PhrasebookData.search(query: searchQuery)
    }

    /// Whether search is active
    var isSearching: Bool {
        !searchQuery.isEmpty
    }

    // MARK: - Translation

    /// Translates a phrase to the selected target language
    func translate(_ phrase: Phrase) {
        translationTask?.cancel()

        translationTask = Task {
            await performTranslation(phrase)
        }
    }

    private func performTranslation(_ phrase: Phrase) async {
        isTranslating = true
        errorMessage = nil

        do {
            let result = try await translationService.translate(
                text: phrase.text,
                from: "en", // Phrasebook is always English source
                to: targetLanguage.code
            )

            guard !Task.isCancelled else { return }

            currentTranslation = PhraseTranslation(
                phrase: phrase,
                translatedText: result.translatedText,
                targetLanguage: targetLanguage
            )

        } catch is CancellationError {
            return
        } catch let error as TranslationError {
            guard !Task.isCancelled else { return }
            handleError(error.localizedDescription)
        } catch {
            guard !Task.isCancelled else { return }
            handleError(error.localizedDescription)
        }

        isTranslating = false
    }

    /// Clears the current translation
    func clearTranslation() {
        translationTask?.cancel()
        currentTranslation = nil
        isTranslating = false
    }

    // MARK: - Text-to-Speech

    /// Speaks the original phrase in English
    func speakOriginal(_ phrase: Phrase) {
        textToSpeechService.stop()
        textToSpeechService.speak(text: phrase.text, languageCode: "en-US")
    }

    /// Speaks the translated text
    func speakTranslation() {
        guard let translation = currentTranslation else { return }
        textToSpeechService.stop()
        textToSpeechService.speak(
            text: translation.translatedText,
            languageCode: translation.targetLanguage.speechLocaleCode
        )
    }

    /// Stops any current speech
    func stopSpeaking() {
        textToSpeechService.stop()
    }

    // MARK: - Clipboard

    /// Copies the translated text to clipboard
    func copyTranslation() {
        guard let translation = currentTranslation else { return }
        UIPasteboard.general.string = translation.translatedText
    }

    /// Copies the original phrase to clipboard
    func copyOriginal(_ phrase: Phrase) {
        UIPasteboard.general.string = phrase.text
    }

    // MARK: - Error Handling

    private func handleError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Translation Result Model

/// Represents a translated phrase
struct PhraseTranslation: Identifiable, Equatable {
    let id = UUID()
    let phrase: Phrase
    let translatedText: String
    let targetLanguage: Language
    let timestamp: Date = Date()
}

// MARK: - Preview Helpers

#if DEBUG
extension PhrasebookViewModel {
    static var preview: PhrasebookViewModel {
        let vm = PhrasebookViewModel(translationService: MockTranslationService())
        return vm
    }

    static var previewWithTranslation: PhrasebookViewModel {
        let vm = PhrasebookViewModel(translationService: MockTranslationService())
        vm.currentTranslation = PhraseTranslation(
            phrase: Phrase(text: "Hello", context: "Greeting"),
            translatedText: "Hola",
            targetLanguage: Language.find(byCode: "es")!
        )
        return vm
    }

    static var previewLoading: PhrasebookViewModel {
        let vm = PhrasebookViewModel(translationService: MockTranslationService())
        vm.setTranslatingForPreview(true)
        return vm
    }

    /// Helper for previews to set isTranslating state
    func setTranslatingForPreview(_ value: Bool) {
        isTranslating = value
    }
}
#endif
