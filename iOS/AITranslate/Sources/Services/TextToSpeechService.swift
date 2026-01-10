import Foundation
import AVFoundation

// MARK: - Protocol

/// Protocol for text-to-speech services
protocol TextToSpeechServiceProtocol: AnyObject {
    /// Whether speech is currently playing
    var isSpeaking: Bool { get }

    /// Delegate for receiving TTS events
    var delegate: TextToSpeechDelegate? { get set }

    /// Speaks the given text in the specified language
    /// - Parameters:
    ///   - text: Text to speak
    ///   - languageCode: BCP-47 language code (e.g., "en-US", "es-ES")
    ///   - rate: Speech rate (0.0-1.0, default 0.5)
    func speak(text: String, languageCode: String, rate: Float)

    /// Stops any current speech
    func stop()

    /// Pauses current speech
    func pause()

    /// Resumes paused speech
    func resume()
}

extension TextToSpeechServiceProtocol {
    func speak(text: String, languageCode: String) {
        speak(text: text, languageCode: languageCode, rate: 0.5)
    }
}

// MARK: - Delegate

/// Delegate protocol for receiving TTS events
protocol TextToSpeechDelegate: AnyObject {
    /// Called when speech starts
    func textToSpeechDidStart()

    /// Called when speech finishes
    func textToSpeechDidFinish()

    /// Called when speech is cancelled
    func textToSpeechDidCancel()

    /// Called when an error occurs
    func textToSpeech(didFailWithError error: TextToSpeechError)

    /// Called with the word range currently being spoken
    func textToSpeech(willSpeakRangeOfSpeechString range: NSRange)
}

// Default implementations for optional delegate methods
extension TextToSpeechDelegate {
    func textToSpeech(willSpeakRangeOfSpeechString range: NSRange) {}
}

// MARK: - Errors

/// Errors that can occur during text-to-speech
enum TextToSpeechError: LocalizedError {
    case noVoiceAvailable(String)
    case audioSessionError(Error)
    case emptyText

    var errorDescription: String? {
        switch self {
        case .noVoiceAvailable(let code):
            return "No voice available for language: \(code)"
        case .audioSessionError(let error):
            return "Audio error: \(error.localizedDescription)"
        case .emptyText:
            return "No text to speak."
        }
    }
}

// MARK: - Implementation

/// Text-to-speech service using AVSpeechSynthesizer
final class TextToSpeechService: NSObject, TextToSpeechServiceProtocol {

    // MARK: - Properties

    weak var delegate: TextToSpeechDelegate?

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    var isPaused: Bool {
        synthesizer.isPaused
    }

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var currentLanguageCode: String?

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public Methods

    func speak(text: String, languageCode: String, rate: Float = 0.5) {
        #if DEBUG
        print("[TTS] speak() called with text: '\(text.prefix(50))...' language: \(languageCode)")
        #endif

        // Validate text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            #if DEBUG
            print("[TTS] Error: Empty text")
            #endif
            delegate?.textToSpeech(didFailWithError: .emptyText)
            return
        }

        // Stop any current speech
        if synthesizer.isSpeaking {
            #if DEBUG
            print("[TTS] Stopping current speech")
            #endif
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Configure audio session for playback
        do {
            try configureAudioSession()
            #if DEBUG
            print("[TTS] Audio session configured successfully")
            #endif
        } catch {
            #if DEBUG
            print("[TTS] Audio session error: \(error)")
            #endif
            delegate?.textToSpeech(didFailWithError: .audioSessionError(error))
            return
        }

        // Find best voice for language
        guard let voice = bestVoice(for: languageCode) else {
            #if DEBUG
            print("[TTS] No voice available for: \(languageCode)")
            #endif
            delegate?.textToSpeech(didFailWithError: .noVoiceAvailable(languageCode))
            return
        }

        #if DEBUG
        print("[TTS] Using voice: \(voice.name) (\(voice.language))")
        #endif

        currentLanguageCode = languageCode

        // Create and configure utterance for natural speech
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice

        // Use a natural speaking rate - slightly slower than default for clarity
        // AVSpeechUtteranceDefaultSpeechRate is 0.5, we use 0.48-0.52 range
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96

        // Natural pitch - avoid too high (robotic) or too low (unnatural)
        utterance.pitchMultiplier = 1.0

        // Full volume
        utterance.volume = 1.0

        // Minimal delays for responsive speech
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.0

        // Speak
        #if DEBUG
        print("[TTS] Starting speech synthesis")
        #endif
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }

    // MARK: - Private Methods

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()

        // Use playAndRecord category to allow seamless transition between recording and playback
        // This is essential for voice conversation mode where we record speech then play translation
        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
        )
        try audioSession.setActive(true, options: [])
    }

    private func clampRate(_ rate: Float) -> Float {
        // AVSpeechUtterance rate range: 0.0 to 1.0
        // Default rate is AVSpeechUtteranceDefaultSpeechRate (0.5)
        let minRate = AVSpeechUtteranceMinimumSpeechRate
        let maxRate = AVSpeechUtteranceMaximumSpeechRate
        return max(minRate, min(maxRate, rate))
    }

    private func bestVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        // Normalize language code for comparison
        let normalizedCode = languageCode.replacingOccurrences(of: "_", with: "-")
        let languagePrefix = normalizedCode.components(separatedBy: "-").first ?? normalizedCode

        // Filter voices for this language
        let matchingVoices = allVoices.filter {
            $0.language.lowercased() == normalizedCode.lowercased() ||
            $0.language.lowercased().hasPrefix(languagePrefix.lowercased())
        }

        guard !matchingVoices.isEmpty else {
            return nil
        }

        // Sort voices by quality preference
        // Priority: Premium > Enhanced > Default
        // Within same quality, prefer exact language match
        // Also prefer certain high-quality voice identifiers (Siri voices, neural voices)
        let sortedVoices = matchingVoices.sorted { voice1, voice2 in
            let score1 = voiceQualityScore(voice1, targetCode: normalizedCode)
            let score2 = voiceQualityScore(voice2, targetCode: normalizedCode)
            return score1 > score2
        }

        #if DEBUG
        if let best = sortedVoices.first {
            let qualityName: String
            if #available(iOS 16.0, *), best.quality == .premium {
                qualityName = "premium"
            } else if best.quality == .enhanced {
                qualityName = "enhanced"
            } else {
                qualityName = "default"
            }
            print("[TTS] Selected voice: \(best.name) (quality: \(qualityName), language: \(best.language), id: \(best.identifier))")
        }
        #endif

        return sortedVoices.first
    }

    /// Calculates a quality score for voice selection
    /// Higher scores indicate better/more natural voices
    private func voiceQualityScore(_ voice: AVSpeechSynthesisVoice, targetCode: String) -> Int {
        var score = 0

        // Base quality score
        if #available(iOS 16.0, *) {
            if voice.quality == .premium {
                score += 100  // Premium voices are the best (neural TTS)
            }
        }
        if voice.quality == .enhanced {
            score += 50  // Enhanced voices are good
        }

        // Exact language match bonus
        if voice.language.lowercased() == targetCode.lowercased() {
            score += 20
        }

        // Prefer voices with "premium", "enhanced", or "compact" in identifier
        // These are typically the newer, higher quality voices
        let identifier = voice.identifier.lowercased()
        if identifier.contains("premium") {
            score += 80
        } else if identifier.contains("enhanced") {
            score += 40
        }

        // Prefer voices that are NOT "compact" (compact = lower quality)
        if identifier.contains("compact") {
            score -= 30
        }

        // Some specific high-quality voice names to prefer
        let voiceName = voice.name.lowercased()
        let highQualityNames = ["samantha", "alex", "karen", "daniel", "moira", "tessa", "fiona", "veena"]
        if highQualityNames.contains(where: { voiceName.contains($0) }) {
            score += 15
        }

        return score
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          didStart utterance: AVSpeechUtterance) {
        #if DEBUG
        print("[TTS] Speech started")
        #endif
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.textToSpeechDidStart()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          didFinish utterance: AVSpeechUtterance) {
        #if DEBUG
        print("[TTS] Speech finished")
        #endif
        // Don't deactivate audio session - keep it active for voice conversation mode
        // This allows seamless transition back to recording
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.textToSpeechDidFinish()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          didCancel utterance: AVSpeechUtterance) {
        #if DEBUG
        print("[TTS] Speech cancelled")
        #endif
        // Don't deactivate audio session - keep it active for voice conversation mode
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.textToSpeechDidCancel()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          willSpeakRangeOfSpeechString characterRange: NSRange,
                          utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.textToSpeech(willSpeakRangeOfSpeechString: characterRange)
        }
    }
}

// MARK: - Voice Information

extension TextToSpeechService {

    /// Returns all available voices
    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
    }

    /// Returns voices for a specific language
    static func voices(for languageCode: String) -> [AVSpeechSynthesisVoice] {
        let normalizedCode = languageCode.replacingOccurrences(of: "_", with: "-")
        let languagePrefix = normalizedCode.components(separatedBy: "-").first ?? normalizedCode

        return availableVoices.filter {
            $0.language.lowercased().hasPrefix(languagePrefix.lowercased())
        }
    }

    /// Returns unique supported language codes
    static var supportedLanguages: [String] {
        let languages = Set(availableVoices.map { $0.language })
        return Array(languages).sorted()
    }

    /// Checks if a language is supported for TTS
    static func isLanguageSupported(_ languageCode: String) -> Bool {
        !voices(for: languageCode).isEmpty
    }
}

// MARK: - Async/Await Extension

extension TextToSpeechService {

    /// Speaks text and waits for completion
    /// - Parameters:
    ///   - text: Text to speak
    ///   - languageCode: BCP-47 language code
    ///   - rate: Speech rate (0.0-1.0)
    func speakAsync(text: String, languageCode: String, rate: Float = 0.5) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let asyncDelegate = AsyncDelegate(continuation: continuation)
            self.delegate = asyncDelegate

            // Keep a strong reference to prevent deallocation
            asyncDelegate.retainSelf = asyncDelegate

            self.speak(text: text, languageCode: languageCode, rate: rate)
        }
    }

    /// Helper delegate for async/await
    private class AsyncDelegate: TextToSpeechDelegate {
        let continuation: CheckedContinuation<Void, Error>
        var retainSelf: AsyncDelegate?

        init(continuation: CheckedContinuation<Void, Error>) {
            self.continuation = continuation
        }

        func textToSpeechDidStart() {}

        func textToSpeechDidFinish() {
            retainSelf = nil
            continuation.resume()
        }

        func textToSpeechDidCancel() {
            retainSelf = nil
            continuation.resume()
        }

        func textToSpeech(didFailWithError error: TextToSpeechError) {
            retainSelf = nil
            continuation.resume(throwing: error)
        }
    }
}
