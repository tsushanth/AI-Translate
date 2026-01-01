import Foundation
import SwiftUI
import AudioToolbox

/// Side of the conversation
enum ConversationSide: Equatable {
    case left
    case right
}

/// A message in the conversation
struct ConversationMessage: Identifiable, Equatable {
    let id = UUID()
    let originalText: String
    let translatedText: String
    let side: ConversationSide
    let sourceLanguage: Language
    let targetLanguage: Language
    let wordType: String?
    let additionalInfo: String?
    let timestamp: Date

    init(
        originalText: String,
        translatedText: String,
        side: ConversationSide,
        sourceLanguage: Language,
        targetLanguage: Language,
        wordType: String? = nil,
        additionalInfo: String? = nil
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.side = side
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.wordType = wordType
        self.additionalInfo = additionalInfo
        self.timestamp = Date()
    }
}

/// ViewModel for voice conversation translation
@MainActor
final class VoiceConversationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var leftLanguage: Language = Language.find(byCode: "en") ?? Language.supportedLanguages[0]
    @Published var rightLanguage: Language = Language.find(byCode: "es") ?? Language.supportedLanguages[1]

    @Published private(set) var messages: [ConversationMessage] = []
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var currentRecordingLanguage: ConversationSide?
    @Published private(set) var isSpeaking: Bool = false

    @Published var showError: Bool = false
    @Published var errorMessage: String?
    @Published var showPermissionAlert: Bool = false

    // MARK: - Services

    private let translationService: TranslationService
    private let speechRecognitionService: SpeechRecognitionService
    private let textToSpeechService: TextToSpeechService

    // MARK: - Private State

    private var currentSide: ConversationSide?
    private var recognizedText: String = ""

    // MARK: - Initialization

    init() {
        self.translationService = RemoteTranslationService()
        self.speechRecognitionService = SpeechRecognitionService()
        self.textToSpeechService = TextToSpeechService()

        speechRecognitionService.delegate = self
        textToSpeechService.delegate = self
    }

    // MARK: - Recording

    func toggleRecording(for side: ConversationSide) async {
        if isRecording && currentRecordingLanguage == side {
            stopRecording()
        } else if !isRecording {
            await startRecording(for: side)
        }
    }

    private func startRecording(for side: ConversationSide) async {
        // Stop any ongoing TTS
        if isSpeaking {
            textToSpeechService.stop()
        }

        // Check and request permissions
        let status = await speechRecognitionService.requestAuthorization()

        guard status == .authorized else {
            if status == .denied || status == .restricted {
                showPermissionAlert = true
            } else {
                handleError(status.userFacingMessage)
            }
            return
        }

        currentSide = side
        currentRecordingLanguage = side
        recognizedText = ""

        // Determine language for recognition
        let language = side == .left ? leftLanguage : rightLanguage

        do {
            // Play audio feedback to indicate listening started
            playRecordingStartSound()

            try speechRecognitionService.startRecording(languageCode: language.speechLocaleCode)
        } catch let error as SpeechRecognitionError {
            handleError(error.localizedDescription)
        } catch {
            handleError(error.localizedDescription)
        }
    }

    /// Plays a system sound to indicate recording has started
    private func playRecordingStartSound() {
        // Play the "begin recording" system sound (similar to Voice Memos)
        AudioServicesPlaySystemSound(1113) // This is the "begin recording" sound
    }

    func stopRecording() {
        speechRecognitionService.stopRecording()
    }

    // MARK: - Translation

    private func translateAndSpeak(_ text: String, from side: ConversationSide) async {
        let sourceLanguage = side == .left ? leftLanguage : rightLanguage
        let targetLanguage = side == .left ? rightLanguage : leftLanguage

        #if DEBUG
        print("[VoiceVM] translateAndSpeak called with: '\(text)'")
        print("[VoiceVM] Source: \(sourceLanguage.code), Target: \(targetLanguage.code)")
        #endif

        do {
            let result = try await translationService.translate(
                text: text,
                from: sourceLanguage.code,
                to: targetLanguage.code
            )

            #if DEBUG
            print("[VoiceVM] Translation result: '\(result.translatedText)'")
            #endif

            // Add message to conversation
            let message = ConversationMessage(
                originalText: text,
                translatedText: result.translatedText,
                side: side,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )

            messages.append(message)

            // Delay to ensure audio session is ready for playback after recording stops
            // The recording audio session needs to fully deactivate first
            #if DEBUG
            print("[VoiceVM] Waiting for audio session transition...")
            #endif
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            #if DEBUG
            print("[VoiceVM] Calling TTS speak with language: \(targetLanguage.speechLocaleCode)")
            #endif

            // Speak the translation aloud
            textToSpeechService.speak(
                text: result.translatedText,
                languageCode: targetLanguage.speechLocaleCode
            )

        } catch {
            #if DEBUG
            print("[VoiceVM] Translation error: \(error)")
            #endif
            handleError("Translation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions

    func clearConversation() {
        messages.removeAll()
    }

    // MARK: - Error Handling

    private func handleError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - SpeechRecognitionDelegate

extension VoiceConversationViewModel: SpeechRecognitionDelegate {
    nonisolated func speechRecognition(didRecognize text: String, isFinal: Bool) {
        Task { @MainActor in
            #if DEBUG
            print("[VoiceVM] Recognized: '\(text)' (final: \(isFinal))")
            #endif

            recognizedText = text

            if isFinal, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let side = currentSide {
                    #if DEBUG
                    print("[VoiceVM] Translating and speaking...")
                    #endif
                    await translateAndSpeak(text, from: side)
                }
            }
        }
    }

    nonisolated func speechRecognition(didFailWithError error: SpeechRecognitionError) {
        Task { @MainActor in
            #if DEBUG
            print("[VoiceVM] Recognition error: \(error.localizedDescription ?? "Unknown")")
            #endif

            isRecording = false
            currentRecordingLanguage = nil
            handleError(error.localizedDescription)
        }
    }

    nonisolated func speechRecognitionDidStart() {
        Task { @MainActor in
            #if DEBUG
            print("[VoiceVM] Recording started")
            #endif
            isRecording = true
        }
    }

    nonisolated func speechRecognitionDidStop() {
        Task { @MainActor in
            #if DEBUG
            print("[VoiceVM] Recording stopped")
            #endif
            isRecording = false
            currentRecordingLanguage = nil
        }
    }
}

// MARK: - TextToSpeechDelegate

extension VoiceConversationViewModel: TextToSpeechDelegate {
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
