import Foundation
import SwiftUI
import Combine
import AudioToolbox
import NaturalLanguage

/// ViewModel for the main translation screen
@MainActor
final class TranslateViewModel: ObservableObject {

    // MARK: - Published State - Text

    /// Source text entered by the user
    @Published var sourceText: String = ""

    /// Translated text result
    @Published var translatedText: String = ""

    // MARK: - Published State - Languages

    /// Selected source language
    @Published var sourceLanguage: Language = .autoDetect

    /// Selected target language
    @Published var targetLanguage: Language = Language.supportedLanguages.first { $0.code == "es" }
        ?? Language.supportedLanguages[0]

    /// Detected language (when using auto-detect)
    @Published private(set) var detectedLanguage: Language?

    // MARK: - Published State - Loading & Errors

    /// Whether a translation is in progress
    @Published private(set) var isTranslating: Bool = false

    /// Whether speech recognition is active
    @Published private(set) var isRecording: Bool = false

    /// Whether TTS is playing
    @Published private(set) var isSpeaking: Bool = false

    /// Current error message to display
    @Published var errorMessage: String?

    /// Whether to show error alert
    @Published var showError: Bool = false

    /// Whether the current translation is favorited
    @Published private(set) var isFavorite: Bool = false

    /// Current entry ID (if saved to history)
    private var currentEntryId: UUID?

    // MARK: - Published State - Permissions

    /// Speech permission status
    @Published private(set) var speechPermissionStatus: SpeechRecognitionAuthStatus = .notDetermined

    // MARK: - Dependencies

    private let translationService: TranslationService
    private let speechRecognitionService: SpeechRecognitionService
    private let textToSpeechService: CloudTTSService
    private let historyStore: HistoryStore
    private let settings: SettingsStore
    private let languageDetectionService: LanguageDetectionService
    private let networkMonitor: NetworkMonitor

    // MARK: - Private State

    private var translationTask: Task<Void, Never>?
    private var languageDetectionTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        translationService: TranslationService = RemoteTranslationService(),
        speechRecognitionService: SpeechRecognitionService = SpeechRecognitionService(),
        textToSpeechService: CloudTTSService = CloudTTSService(),
        historyStore: HistoryStore = .shared,
        settings: SettingsStore = .shared,
        languageDetectionService: LanguageDetectionService = .shared,
        networkMonitor: NetworkMonitor = .shared
    ) {
        self.translationService = translationService
        self.speechRecognitionService = speechRecognitionService
        self.textToSpeechService = textToSpeechService
        self.historyStore = historyStore
        self.settings = settings
        self.languageDetectionService = languageDetectionService
        self.networkMonitor = networkMonitor

        // Set initial source language based on auto-detect setting
        if settings.autoDetectLanguage {
            self.sourceLanguage = .autoDetect
        }

        setupBindings()
        setupSpeechDelegates()
        updatePermissionStatus()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Reset favorite status when text changes
        $sourceText
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.isFavorite = false
                self?.currentEntryId = nil
            }
            .store(in: &cancellables)

        // Real-time language detection when source language is set to auto
        $sourceText
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.performLocalLanguageDetection(text)
            }
            .store(in: &cancellables)
    }

    /// Performs local language detection using NLLanguageRecognizer
    /// This is instant and works completely offline
    private func performLocalLanguageDetection(_ text: String) {
        // Only detect if using auto-detect mode
        guard sourceLanguage.code == "auto" else {
            return
        }

        // Cancel any pending detection task
        languageDetectionTask?.cancel()

        languageDetectionTask = Task {
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Need enough text for reliable detection
            guard trimmedText.count >= 5 else {
                if detectedLanguage != nil {
                    detectedLanguage = nil
                }
                return
            }

            // Detect language locally
            if let result = languageDetectionService.detectLanguageWithConfidence(trimmedText) {
                // Only update if confidence is reasonable (> 50%)
                if result.confidence > 0.5 {
                    let detected = Language.find(byCode: result.languageCode)
                    if detected != detectedLanguage {
                        detectedLanguage = detected

                        #if DEBUG
                        print("[TranslateVM] Local detection: \(result.languageCode) (\(String(format: "%.0f%%", result.confidence * 100)))")
                        #endif
                    }
                }
            }
        }
    }

    private func setupSpeechDelegates() {
        speechRecognitionService.delegate = self
        textToSpeechService.delegate = self
    }

    private func updatePermissionStatus() {
        speechPermissionStatus = speechRecognitionService.authorizationStatus
    }

    // MARK: - Translation

    /// Translates the current source text
    func translate() {
        // Cancel any in-flight translation
        translationTask?.cancel()

        // Validate input
        let trimmedText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            translatedText = ""
            detectedLanguage = nil
            return
        }

        translationTask = Task {
            await performTranslation()
        }
    }

    private func performTranslation() async {
        isTranslating = true
        errorMessage = nil

        // When offline, try to use cached translation from history
        if !networkMonitor.isOnline {
            let effectiveSourceCode = detectedLanguage?.code ?? sourceLanguage.code
            if let cached = historyStore.findCachedTranslation(
                text: sourceText,
                sourceLanguage: effectiveSourceCode,
                targetLanguage: targetLanguage.code
            ) {
                translatedText = cached.translatedText

                // Update detected language from cache
                if let detectedCode = cached.detectedLanguage {
                    detectedLanguage = Language.find(byCode: detectedCode)
                }

                HapticFeedback.success()
                isTranslating = false

                #if DEBUG
                print("[TranslateVM] Used cached translation (offline)")
                #endif
                return
            }
        }

        do {
            let result = try await translationService.translate(
                text: sourceText,
                from: sourceLanguage.code,
                to: targetLanguage.code
            )

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            translatedText = result.translatedText

            // Update detected language
            if let detectedCode = result.detectedLanguage {
                detectedLanguage = Language.find(byCode: detectedCode)
            } else {
                detectedLanguage = nil
            }

            // Haptic feedback on successful translation
            HapticFeedback.success()

            // Save to history
            saveToHistory()

            // Track language pair usage for smart pre-caching
            let effectiveSourceCode = result.detectedLanguage ?? sourceLanguage.code
            settings.recordLanguagePairUsage(source: effectiveSourceCode, target: targetLanguage.code)

        } catch is CancellationError {
            return
        } catch let error as TranslationError {
            guard !Task.isCancelled else { return }
            // When offline and no cache available, show helpful message
            if !networkMonitor.isOnline {
                handleError("You're offline. This translation isn't in your history cache.")
            } else {
                handleError(error.localizedDescription)
            }
        } catch {
            guard !Task.isCancelled else { return }
            if !networkMonitor.isOnline {
                handleError("You're offline. This translation isn't in your history cache.")
            } else {
                handleError(error.localizedDescription)
            }
        }

        isTranslating = false
    }

    // MARK: - Language Management

    /// Swaps source and target languages
    func swapLanguages() {
        // Can't swap if using auto-detect without a detection
        guard sourceLanguage.code != "auto" || detectedLanguage != nil else {
            return
        }

        let effectiveSource = detectedLanguage ?? sourceLanguage

        // Swap languages
        let temp = targetLanguage
        targetLanguage = effectiveSource
        sourceLanguage = temp

        // Swap text
        let tempText = translatedText
        translatedText = sourceText
        sourceText = tempText

        // Reset detection
        detectedLanguage = nil
        isFavorite = false
        currentEntryId = nil

        // Haptic feedback
        HapticFeedback.medium()
    }

    /// Whether swap is available
    var canSwapLanguages: Bool {
        sourceLanguage.code != "auto" || detectedLanguage != nil
    }

    // MARK: - Speech Recognition

    /// Starts voice input
    func startVoiceInput() async {
        // Stop TTS if playing
        if isSpeaking {
            stopSpeaking()
        }

        // Check and request permissions
        let status = await speechRecognitionService.requestAuthorization()
        speechPermissionStatus = status

        guard status == .authorized else {
            handleError(status.userFacingMessage)
            return
        }

        // Determine language for recognition
        let languageCode: String
        if sourceLanguage.code == "auto" {
            // Default to device language or English for auto-detect
            languageCode = Locale.current.language.languageCode?.identifier ?? "en-US"
        } else {
            languageCode = sourceLanguage.speechLocaleCode
        }

        do {
            // Play start recording sound
            playRecordingStartSound()
            try speechRecognitionService.startRecording(languageCode: languageCode)
        } catch let error as SpeechRecognitionError {
            handleError(error.localizedDescription)
        } catch {
            handleError(error.localizedDescription)
        }
    }

    /// Stops voice input
    func stopVoiceInput() {
        playRecordingStopSound()
        speechRecognitionService.stopRecording()
    }

    /// Plays a system sound to indicate recording has started
    private func playRecordingStartSound() {
        AudioServicesPlaySystemSound(1113)
    }

    /// Plays a system sound to indicate recording has stopped
    private func playRecordingStopSound() {
        AudioServicesPlaySystemSound(1114)
    }

    /// Toggles voice input
    func toggleVoiceInput() async {
        if isRecording {
            stopVoiceInput()
        } else {
            await startVoiceInput()
        }
    }

    // MARK: - Text-to-Speech

    /// Speaks the translated text
    func speakTranslation() {
        guard !translatedText.isEmpty else { return }

        // Stop recording if active
        if isRecording {
            stopVoiceInput()
        }

        textToSpeechService.speak(
            text: translatedText,
            languageCode: targetLanguage.speechLocaleCode
        )
    }

    /// Speaks the source text
    func speakSource() {
        guard !sourceText.isEmpty else { return }

        let languageCode = (detectedLanguage ?? sourceLanguage).speechLocaleCode
        textToSpeechService.speak(text: sourceText, languageCode: languageCode)
    }

    /// Stops TTS playback
    func stopSpeaking() {
        textToSpeechService.stop()
    }

    /// Toggles TTS for translation
    func toggleSpeakTranslation() {
        if isSpeaking {
            stopSpeaking()
        } else {
            speakTranslation()
        }
    }

    // MARK: - Favorites

    /// Toggles favorite status for current translation
    func toggleFavorite() {
        guard !sourceText.isEmpty, !translatedText.isEmpty else { return }

        if let entryId = currentEntryId {
            // Update existing entry
            historyStore.toggleFavorite(id: entryId)
            isFavorite = historyStore.find(id: entryId)?.isFavorite ?? false
        } else {
            // Save new entry as favorite
            let entry = createHistoryEntry(isFavorite: true)
            historyStore.add(entry)
            currentEntryId = entry.id
            isFavorite = true
        }

        // Haptic feedback
        HapticFeedback.light()
    }

    // MARK: - History

    private func saveToHistory() {
        let entry = createHistoryEntry(isFavorite: false)
        historyStore.add(entry)
        currentEntryId = entry.id
    }

    private func createHistoryEntry(isFavorite: Bool) -> TranslationEntry {
        TranslationEntry(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage.code,
            targetLanguage: targetLanguage.code,
            detectedLanguage: detectedLanguage?.code,
            isFavorite: isFavorite
        )
    }

    /// Loads a history entry into the view
    func loadEntry(_ entry: TranslationEntry) {
        sourceText = entry.sourceText
        translatedText = entry.translatedText
        sourceLanguage = Language.find(byCode: entry.sourceLanguage) ?? .autoDetect
        targetLanguage = Language.find(byCode: entry.targetLanguage) ?? Language.supportedLanguages[0]
        detectedLanguage = entry.detectedLanguage.flatMap { Language.find(byCode: $0) }
        isFavorite = entry.isFavorite
        currentEntryId = entry.id
    }

    // MARK: - Clear & Reset

    /// Clears all text and resets state
    func clear() {
        translationTask?.cancel()
        stopVoiceInput()
        stopSpeaking()

        sourceText = ""
        translatedText = ""
        detectedLanguage = nil
        errorMessage = nil
        isTranslating = false
        isFavorite = false
        currentEntryId = nil
    }

    // MARK: - Clipboard

    /// Copies translated text to clipboard
    func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        UIPasteboard.general.string = translatedText
        HapticFeedback.light()
    }

    /// Copies source text to clipboard
    func copySource() {
        guard !sourceText.isEmpty else { return }
        UIPasteboard.general.string = sourceText
        HapticFeedback.light()
    }

    /// Pastes text from clipboard into source
    func pasteFromClipboard() {
        if let text = UIPasteboard.general.string {
            sourceText = text
        }
    }

    // MARK: - Error Handling

    private func handleError(_ message: String) {
        errorMessage = message
        showError = true
        HapticFeedback.error()

        #if DEBUG
        print("[TranslateViewModel] Error: \(message)")
        #endif
    }

    // MARK: - Computed Properties

    /// Whether translate button should be enabled
    var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating
    }

    /// Whether there's content to display
    var hasContent: Bool {
        !sourceText.isEmpty || !translatedText.isEmpty
    }

    /// Source language display text
    var sourceLanguageDisplay: String {
        if sourceLanguage.code == "auto", let detected = detectedLanguage {
            return "Detected: \(detected.shortDisplayName)"
        }
        return sourceLanguage.shortDisplayName
    }
}

// MARK: - SpeechRecognitionDelegate

extension TranslateViewModel: SpeechRecognitionDelegate {

    nonisolated func speechRecognition(didRecognize text: String, isFinal: Bool) {
        Task { @MainActor in
            sourceText = text
            if isFinal {
                translate()
            }
        }
    }

    nonisolated func speechRecognition(didFailWithError error: SpeechRecognitionError) {
        Task { @MainActor in
            isRecording = false
            handleError(error.localizedDescription)
        }
    }

    nonisolated func speechRecognitionDidStart() {
        Task { @MainActor in
            isRecording = true
        }
    }

    nonisolated func speechRecognitionDidStop() {
        Task { @MainActor in
            isRecording = false
        }
    }
}

// MARK: - TextToSpeechDelegate

extension TranslateViewModel: TextToSpeechDelegate {

    nonisolated func textToSpeechDidStart() {
        Task { @MainActor in
            isSpeaking = true
        }
    }

    nonisolated func textToSpeechDidFinish() {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    nonisolated func textToSpeechDidCancel() {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    nonisolated func textToSpeech(didFailWithError error: TextToSpeechError) {
        Task { @MainActor in
            isSpeaking = false
            handleError(error.localizedDescription)
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension TranslateViewModel {
    /// Creates a view model with mock data for previews
    static var preview: TranslateViewModel {
        let vm = TranslateViewModel(
            translationService: MockTranslationService(),
            historyStore: HistoryStore.preview,
            settings: .shared
        )
        vm.sourceText = "Hello, how are you?"
        vm.translatedText = "Hola, ¿cómo estás?"
        vm.sourceLanguage = Language.find(byCode: "en")!
        vm.targetLanguage = Language.find(byCode: "es")!
        return vm
    }

    static var previewEmpty: TranslateViewModel {
        TranslateViewModel(
            translationService: MockTranslationService(),
            historyStore: HistoryStore.preview,
            settings: .shared
        )
    }

    static var previewLoading: TranslateViewModel {
        let vm = TranslateViewModel(
            translationService: MockTranslationService(),
            historyStore: HistoryStore.preview,
            settings: .shared
        )
        vm.sourceText = "Translating..."
        vm.isTranslating = true
        return vm
    }

    static var previewRecording: TranslateViewModel {
        let vm = TranslateViewModel(
            translationService: MockTranslationService(),
            historyStore: HistoryStore.preview,
            settings: .shared
        )
        vm.isRecording = true
        return vm
    }
}

/// Mock translation service for previews and testing
final class MockTranslationService: TranslationService {
    var shouldFail = false
    var delay: UInt64 = 500_000_000 // 0.5 seconds

    func translate(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> TranslationResult {
        try await Task.sleep(nanoseconds: delay)

        if shouldFail {
            throw TranslationError.networkError(
                underlying: URLError(.notConnectedToInternet)
            )
        }

        return TranslationResult(
            translatedText: "[Mock] Translated: \(text)",
            sourceLanguage: sourceLanguage == "auto" ? "en" : sourceLanguage,
            targetLanguage: targetLanguage,
            detectedLanguage: sourceLanguage == "auto" ? "en" : nil,
            confidence: sourceLanguage == "auto" ? 0.95 : nil,
            characterCount: text.count,
            requestId: UUID().uuidString,
            processingTimeMs: 150
        )
    }
}
#endif
