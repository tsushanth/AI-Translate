import Foundation
import SwiftUI
import AudioToolbox
import UIKit
import Network

/// Side of the conversation
enum ConversationSide: Hashable {
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

    private let remoteTranslationService: TranslationService
    private let speechRecognitionService: SpeechRecognitionService
    private let ttsManager: TTSManager

    // Offline services (iOS 17.4+)
    private var appleTranslationService: (any TranslationService)?

    // MARK: - Private State

    private var currentSide: ConversationSide?
    private var recognizedText: String = ""

    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.sayitai.voicevm.network")
    @Published private(set) var isOnline: Bool = true

    // Offline mode
    @Published private(set) var isOfflineMode: Bool = false

    // MARK: - Initialization

    init() {
        self.remoteTranslationService = RemoteTranslationService()
        self.speechRecognitionService = SpeechRecognitionService()
        self.ttsManager = TTSManager.shared

        // Initialize Apple Translation service if available (iOS 18.0+)
        if #available(iOS 18.0, *) {
            self.appleTranslationService = AppleTranslationService()
        }

        speechRecognitionService.delegate = self
        ttsManager.delegate = self

        // Start network monitoring
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = online
                #if DEBUG
                print("[VoiceVM] Network status: \(online ? "Online" : "Offline")")
                #endif
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    /// Check if offline translation is available for current language pair
    func canTranslateOffline() async -> Bool {
        guard #available(iOS 18.0, *) else { return false }

        // Check if we have downloaded models
        guard OfflineModelManager.shared.downloadedPackage?.includesAppleTranslation == true else {
            return false
        }

        // Check if Apple Translation supports this language pair
        let leftCode = leftLanguage.code
        let rightCode = rightLanguage.code

        // Check both directions (left->right and right->left)
        let leftToRight = await AppleTranslationService.isOfflineAvailable(from: leftCode, to: rightCode)
        if leftToRight { return true }

        let rightToLeft = await AppleTranslationService.isOfflineAvailable(from: rightCode, to: leftCode)
        return rightToLeft
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
            ttsManager.stop()
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

        // Only force on-device recognition when there's no internet
        // When online, allow server fallback for better accuracy
        speechRecognitionService.requireOnDeviceRecognition = !isOnline

        #if DEBUG
        print("[VoiceVM] Starting recording - online: \(isOnline), on-device required: \(!isOnline)")
        #endif

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

    /// Plays a system sound to indicate recording has stopped
    private func playRecordingStopSound() {
        // Play the "end recording" system sound
        AudioServicesPlaySystemSound(1114) // This is the "end recording" sound
    }

    func stopRecording() {
        playRecordingStopSound()
        speechRecognitionService.stopRecording()
    }

    // MARK: - Translation

    private func translateAndSpeak(_ text: String, from side: ConversationSide) async {
        let sourceLanguage = side == .left ? leftLanguage : rightLanguage
        let targetLanguage = side == .left ? rightLanguage : leftLanguage

        #if DEBUG
        print("[VoiceVM] translateAndSpeak called with: '\(text)'")
        print("[VoiceVM] Source: \(sourceLanguage.code), Target: \(targetLanguage.code)")
        print("[VoiceVM] Offline mode: \(isOfflineMode), Online: \(isOnline)")
        #endif

        do {
            // Select translation service based on mode and availability
            let translationService = await selectTranslationService(
                from: sourceLanguage.code,
                to: targetLanguage.code
            )

            #if DEBUG
            print("[VoiceVM] Using translation service: \(type(of: translationService))")
            #endif

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

            // Speak the translation aloud using TTSManager (handles offline fallback)
            ttsManager.speak(
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

    /// Select the appropriate translation service based on network status and availability
    private func selectTranslationService(from sourceCode: String, to targetCode: String) async -> any TranslationService {
        // Only use Apple Translation when there's NO internet connection
        // When online, always prefer the remote service for better quality
        if !isOnline {
            if #available(iOS 18.0, *),
               let appleService = appleTranslationService,
               await AppleTranslationService.isOfflineAvailable(from: sourceCode, to: targetCode) {
                #if DEBUG
                print("[VoiceVM] Using Apple Translation (offline - no internet)")
                #endif
                return appleService
            }

            // No offline translation available and network is down
            #if DEBUG
            print("[VoiceVM] No offline translation available, but network is down")
            #endif
        }

        // Default to remote service when online
        #if DEBUG
        print("[VoiceVM] Using Remote Translation Service (online)")
        #endif
        return remoteTranslationService
    }

    // MARK: - Actions

    func clearConversation() {
        messages.removeAll()
    }

    /// Speak a specific message's translation
    func speakMessage(_ message: ConversationMessage) {
        // Stop any current speech
        if isSpeaking {
            ttsManager.stop()
        }

        // Speak the translation in the target language using TTSManager
        ttsManager.speak(
            text: message.translatedText,
            languageCode: message.targetLanguage.speechLocaleCode
        )
    }

    /// Copy message text to clipboard
    func copyMessage(_ message: ConversationMessage) {
        let textToCopy = "\(message.originalText)\n\(message.translatedText)"
        UIPasteboard.general.string = textToCopy

        // Play haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Toggle favorite status for a message
    func toggleFavorite(_ message: ConversationMessage) {
        // Play haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // TODO: Save to favorites store
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

    nonisolated func textToSpeech(willSpeakRangeOfSpeechString range: NSRange) {
        // Optional: Could be used for highlighting text being spoken
    }
}
