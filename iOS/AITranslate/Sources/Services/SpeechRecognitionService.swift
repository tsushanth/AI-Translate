import Foundation
import Speech
import AVFoundation

// MARK: - Protocol

/// Protocol for speech recognition services
protocol SpeechRecognitionServiceProtocol: AnyObject {
    /// Current authorization status
    var authorizationStatus: SpeechRecognitionAuthStatus { get }

    /// Whether recording is currently active
    var isRecording: Bool { get }

    /// Delegate for receiving recognition events
    var delegate: SpeechRecognitionDelegate? { get set }

    /// Requests necessary permissions for speech recognition
    func requestAuthorization() async -> SpeechRecognitionAuthStatus

    /// Starts recording and recognizing speech
    /// - Parameter languageCode: BCP-47 language code (e.g., "en-US", "es-ES")
    /// - Throws: SpeechRecognitionError if recording cannot start
    func startRecording(languageCode: String) throws

    /// Stops recording and finalizes recognition
    func stopRecording()
}

// MARK: - Delegate

/// Delegate protocol for receiving speech recognition events
protocol SpeechRecognitionDelegate: AnyObject {
    /// Called when partial or final transcription is available
    /// - Parameters:
    ///   - text: The recognized text
    ///   - isFinal: Whether this is the final transcription
    func speechRecognition(didRecognize text: String, isFinal: Bool)

    /// Called when an error occurs during recognition
    func speechRecognition(didFailWithError error: SpeechRecognitionError)

    /// Called when recording starts
    func speechRecognitionDidStart()

    /// Called when recording stops
    func speechRecognitionDidStop()
}

// MARK: - Authorization Status

/// Combined authorization status for speech and microphone
enum SpeechRecognitionAuthStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case microphoneDenied

    var canRecord: Bool {
        self == .authorized
    }

    var userFacingMessage: String {
        switch self {
        case .notDetermined:
            return "Speech recognition permission is required."
        case .authorized:
            return "Ready to record."
        case .denied:
            return "Speech recognition access was denied. Please enable it in Settings."
        case .restricted:
            return "Speech recognition is restricted on this device."
        case .microphoneDenied:
            return "Microphone access was denied. Please enable it in Settings."
        }
    }
}

// MARK: - Errors

/// Errors that can occur during speech recognition
enum SpeechRecognitionError: LocalizedError {
    case notAuthorized(SpeechRecognitionAuthStatus)
    case languageNotSupported(String)
    case audioEngineError(Error)
    case recognitionError(Error)
    case serviceUnavailable
    case noSpeechDetected
    case alreadyRecording
    case notRecording
    case noInputNode

    var errorDescription: String? {
        switch self {
        case .notAuthorized(let status):
            return status.userFacingMessage
        case .languageNotSupported(let code):
            return "Speech recognition is not available for language: \(code)"
        case .audioEngineError(let error):
            return "Audio error: \(error.localizedDescription)"
        case .recognitionError(let error):
            return "Recognition error: \(error.localizedDescription)"
        case .serviceUnavailable:
            return "Speech recognition service is unavailable. Please check your internet connection and try again."
        case .noSpeechDetected:
            return "No speech was detected. Please try speaking again."
        case .alreadyRecording:
            return "Recording is already in progress."
        case .notRecording:
            return "No recording in progress."
        case .noInputNode:
            return "No audio input available."
        }
    }
}

// MARK: - Implementation

/// Speech recognition service using SFSpeechRecognizer and AVAudioEngine
final class SpeechRecognitionService: NSObject, SpeechRecognitionServiceProtocol {

    // MARK: - Properties

    weak var delegate: SpeechRecognitionDelegate?

    private(set) var isRecording = false

    var authorizationStatus: SpeechRecognitionAuthStatus {
        // Check microphone first
        switch AVAudioSession.sharedInstance().recordPermission {
        case .denied:
            return .microphoneDenied
        case .undetermined:
            // If mic is undetermined, check speech status
            break
        case .granted:
            break
        @unknown default:
            break
        }

        // Check speech recognition
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            // Double-check microphone
            if AVAudioSession.sharedInstance().recordPermission == .granted {
                return .authorized
            }
            return .microphoneDenied
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentRecognizer: SFSpeechRecognizer?

    /// Timer for detecting silence/end of speech
    private var silenceTimer: Timer?
    /// Last time we received a transcription update
    private var lastTranscriptionTime: Date?
    /// The last transcription text (to detect when speech has stopped changing)
    private var lastTranscriptionText: String = ""
    /// Timeout in seconds after which we consider speech finished
    private let silenceTimeout: TimeInterval = 1.5
    /// Flag to prevent duplicate final results
    private var hasSentFinalResult: Bool = false

    // MARK: - Authorization

    func requestAuthorization() async -> SpeechRecognitionAuthStatus {
        // Request microphone permission first
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micStatus else {
            return .microphoneDenied
        }

        // Then request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch speechStatus {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    // MARK: - Recording

    func startRecording(languageCode: String) throws {
        // Check if already recording
        guard !isRecording else {
            throw SpeechRecognitionError.alreadyRecording
        }

        // Check authorization
        let status = authorizationStatus
        guard status.canRecord else {
            throw SpeechRecognitionError.notAuthorized(status)
        }

        // Create recognizer for the specified language
        let locale = Locale(identifier: languageCode)
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable else {
            throw SpeechRecognitionError.languageNotSupported(languageCode)
        }

        currentRecognizer = recognizer

        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionError.audioEngineError(error)
        }

        // Create audio engine and recognition request
        audioEngine = AVAudioEngine()

        guard let audioEngine = audioEngine else {
            throw SpeechRecognitionError.audioEngineError(
                NSError(domain: "SpeechRecognition", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
            )
        }

        let inputNode = audioEngine.inputNode
        guard inputNode.inputFormat(forBus: 0).channelCount > 0 else {
            throw SpeechRecognitionError.noInputNode
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.audioEngineError(
                NSError(domain: "SpeechRecognition", code: -2,
                       userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"])
            )
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure recognition - prefer on-device but allow server fallback
        if #available(iOS 13, *) {
            // Don't require on-device - allow server fallback for better coverage
            recognitionRequest.requiresOnDeviceRecognition = false

            #if DEBUG
            print("[SpeechRecognition] On-device supported: \(recognizer.supportsOnDeviceRecognition)")
            print("[SpeechRecognition] Language: \(languageCode)")
            #endif
        }

        // Add punctuation for better results
        if #available(iOS 14, *) {
            recognitionRequest.addsPunctuation = true
        }

        // Set task hint for better recognition
        if #available(iOS 16, *) {
            recognitionRequest.customizedLanguageModel = nil // Use default model
        }

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }

        // Install audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        do {
            try audioEngine.start()
            isRecording = true

            #if DEBUG
            print("[SpeechRecognition] Audio engine started successfully")
            print("[SpeechRecognition] Input node format: \(inputNode.outputFormat(forBus: 0))")
            #endif

            // Start silence detection timer
            startSilenceDetection()

            DispatchQueue.main.async { [weak self] in
                self?.delegate?.speechRecognitionDidStart()
            }
        } catch {
            #if DEBUG
            print("[SpeechRecognition] Failed to start audio engine: \(error)")
            #endif
            cleanup()
            throw SpeechRecognitionError.audioEngineError(error)
        }
    }

    // MARK: - Silence Detection

    private func startSilenceDetection() {
        lastTranscriptionTime = Date()
        lastTranscriptionText = ""
        hasSentFinalResult = false

        // Run timer on main thread
        DispatchQueue.main.async { [weak self] in
            self?.silenceTimer?.invalidate()
            self?.silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkForSilence()
            }
        }
    }

    private func stopSilenceDetection() {
        DispatchQueue.main.async { [weak self] in
            self?.silenceTimer?.invalidate()
            self?.silenceTimer = nil
        }
    }

    private func checkForSilence() {
        guard isRecording, !hasSentFinalResult, let lastTime = lastTranscriptionTime else { return }

        let timeSinceLastTranscription = Date().timeIntervalSince(lastTime)

        // If we have some text and haven't received updates for silenceTimeout seconds, stop
        if !lastTranscriptionText.isEmpty && timeSinceLastTranscription >= silenceTimeout {
            #if DEBUG
            print("[SpeechRecognition] Silence detected after \(timeSinceLastTranscription)s - auto-stopping")
            #endif

            // Mark that we've sent final result to prevent duplicates
            hasSentFinalResult = true

            // Finalize the current transcription
            let finalText = lastTranscriptionText
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.speechRecognition(didRecognize: finalText, isFinal: true)
            }

            stopRecording()
        }
    }

    private func updateTranscriptionTime(with text: String) {
        // Only update time if the text actually changed
        if text != lastTranscriptionText {
            lastTranscriptionTime = Date()
            lastTranscriptionText = text
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        #if DEBUG
        print("[SpeechRecognition] stopRecording called")
        #endif

        // Stop silence detection
        stopSilenceDetection()

        // Stop audio engine and remove tap
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        // End audio request
        recognitionRequest?.endAudio()

        // Mark as not recording
        isRecording = false

        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.speechRecognitionDidStop()
        }
    }

    // MARK: - Private Methods

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            let nsError = error as NSError

            #if DEBUG
            print("[SpeechRecognition] Error: domain=\(nsError.domain), code=\(nsError.code), desc=\(nsError.localizedDescription)")
            #endif

            // Handle known error codes from kAFAssistantErrorDomain
            if nsError.domain == "kAFAssistantErrorDomain" {
                switch nsError.code {
                case 203, 216:
                    // 203: Cancelled, 216: Recognition was cancelled - ignore
                    #if DEBUG
                    print("[SpeechRecognition] Recognition cancelled (code \(nsError.code))")
                    #endif
                    return
                case 1101, 1107:
                    // 1101/1107: Service unavailable - network issue or service down
                    #if DEBUG
                    print("[SpeechRecognition] Service unavailable")
                    #endif
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.speechRecognition(didFailWithError: .serviceUnavailable)
                    }
                    cleanup()
                    return
                case 1110, 1700:
                    // 1110/1700: No speech detected / timeout
                    #if DEBUG
                    print("[SpeechRecognition] No speech detected")
                    #endif
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.speechRecognition(didFailWithError: .noSpeechDetected)
                    }
                    cleanup()
                    return
                default:
                    break
                }
            }

            DispatchQueue.main.async { [weak self] in
                self?.delegate?.speechRecognition(didFailWithError: .recognitionError(error))
            }
            cleanup()
            return
        }

        guard let result = result else { return }

        let transcription = result.bestTranscription.formattedString

        #if DEBUG
        print("[SpeechRecognition] Recognized: '\(transcription)' (final: \(result.isFinal), alreadySentFinal: \(hasSentFinalResult))")
        #endif

        // Update silence detection timer
        updateTranscriptionTime(with: transcription)

        // Only send if we haven't already sent a final result
        if !hasSentFinalResult {
            if result.isFinal {
                hasSentFinalResult = true
            }

            DispatchQueue.main.async { [weak self] in
                self?.delegate?.speechRecognition(
                    didRecognize: transcription,
                    isFinal: result.isFinal
                )
            }
        }

        if result.isFinal {
            stopSilenceDetection()
            cleanup()
        }
    }

    private func cleanup() {
        stopSilenceDetection()

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        currentRecognizer = nil
        isRecording = false
        lastTranscriptionText = ""
        lastTranscriptionTime = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Async/Await Extension

extension SpeechRecognitionService {

    /// Convenience method that returns recognized text via AsyncStream
    /// - Parameter languageCode: BCP-47 language code
    /// - Returns: AsyncStream of (text, isFinal) tuples
    func recognitionStream(languageCode: String) -> AsyncThrowingStream<(text: String, isFinal: Bool), Error> {
        AsyncThrowingStream { continuation in
            let streamDelegate = StreamDelegate(continuation: continuation)
            self.delegate = streamDelegate

            do {
                try self.startRecording(languageCode: languageCode)

                continuation.onTermination = { [weak self] _ in
                    self?.stopRecording()
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    /// Helper delegate class for AsyncStream
    private class StreamDelegate: SpeechRecognitionDelegate {
        let continuation: AsyncThrowingStream<(text: String, isFinal: Bool), Error>.Continuation

        init(continuation: AsyncThrowingStream<(text: String, isFinal: Bool), Error>.Continuation) {
            self.continuation = continuation
        }

        func speechRecognition(didRecognize text: String, isFinal: Bool) {
            continuation.yield((text: text, isFinal: isFinal))
            if isFinal {
                continuation.finish()
            }
        }

        func speechRecognition(didFailWithError error: SpeechRecognitionError) {
            continuation.finish(throwing: error)
        }

        func speechRecognitionDidStart() {}
        func speechRecognitionDidStop() {}
    }
}

// MARK: - Language Support

extension SpeechRecognitionService {

    /// Returns supported locales for speech recognition
    static var supportedLocales: Set<Locale> {
        SFSpeechRecognizer.supportedLocales()
    }

    /// Checks if a language code is supported
    static func isLanguageSupported(_ languageCode: String) -> Bool {
        let locale = Locale(identifier: languageCode)
        return supportedLocales.contains { $0.identifier.hasPrefix(locale.identifier) }
    }

    /// Suggests the best matching locale for a language code
    static func bestLocale(for languageCode: String) -> Locale? {
        let targetLocale = Locale(identifier: languageCode)

        // Try exact match first
        if let exact = supportedLocales.first(where: { $0.identifier == languageCode }) {
            return exact
        }

        // Try language-only match (e.g., "en" matches "en-US")
        let languageOnly = targetLocale.language.languageCode?.identifier ?? languageCode
        return supportedLocales.first { locale in
            locale.language.languageCode?.identifier == languageOnly
        }
    }
}
