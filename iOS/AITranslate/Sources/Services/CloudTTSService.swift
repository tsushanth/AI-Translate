import Foundation
import AVFoundation

/// Cloud-based Text-to-Speech service using Google Cloud TTS API
/// Provides high-quality neural voices for all supported languages
/// Conforms to TextToSpeechServiceProtocol for drop-in replacement of local TTS
final class CloudTTSService: NSObject, TextToSpeechServiceProtocol {

    // MARK: - Properties

    weak var delegate: TextToSpeechDelegate?

    var isSpeaking: Bool {
        return isPlaying
    }

    private var isPlaying: Bool = false

    // MARK: - Private Properties

    private let session: URLSession
    private let baseURL: URL
    private let deviceId: String

    private var audioPlayer: AVAudioPlayer?
    private var currentTask: URLSessionDataTask?

    // MARK: - Initialization

    init(
        baseURL: URL = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        deviceId: String = AppConfig.deviceId
    ) {
        self.baseURL = baseURL
        self.session = session
        self.deviceId = deviceId
        super.init()
    }

    // MARK: - Public Methods

    /// Speaks the given text using cloud TTS
    /// - Parameters:
    ///   - text: Text to speak
    ///   - languageCode: ISO 639-1 language code (e.g., "en", "es", "fr")
    ///   - rate: Speech rate (0.0-1.0, mapped to cloud TTS range 0.25-4.0)
    func speak(text: String, languageCode: String, rate: Float = 0.5) {
        // Map rate from 0.0-1.0 to cloud TTS range 0.25-4.0
        // 0.5 (default) maps to 1.0 (normal speed)
        let speakingRate = mapRateToCloudTTS(rate)
        #if DEBUG
        print("[CloudTTS] speak() called with text: '\(text.prefix(50))...' language: \(languageCode)")
        #endif

        // Validate text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            delegate?.textToSpeech(didFailWithError: .emptyText)
            return
        }

        // Stop any current playback
        stop()

        // Build request
        guard let request = buildRequest(text: text, languageCode: languageCode, speakingRate: speakingRate) else {
            delegate?.textToSpeech(didFailWithError: .audioSessionError(NSError(domain: "CloudTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to build request"])))
            return
        }

        // Execute request
        currentTask = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.delegate?.textToSpeech(didFailWithError: .audioSessionError(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.delegate?.textToSpeech(didFailWithError: .audioSessionError(NSError(domain: "CloudTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                DispatchQueue.main.async {
                    self.delegate?.textToSpeech(didFailWithError: .audioSessionError(NSError(domain: "CloudTTS", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(message)"])))
                }
                return
            }

            guard let audioData = data, !audioData.isEmpty else {
                DispatchQueue.main.async {
                    self.delegate?.textToSpeech(didFailWithError: .audioSessionError(NSError(domain: "CloudTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty audio response"])))
                }
                return
            }

            #if DEBUG
            print("[CloudTTS] Received audio data: \(audioData.count) bytes")
            #endif

            // Play audio on main thread
            DispatchQueue.main.async {
                self.playAudio(data: audioData)
            }
        }

        currentTask?.resume()
    }

    /// Stops any current speech
    func stop() {
        currentTask?.cancel()
        currentTask = nil

        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            isPlaying = false
            delegate?.textToSpeechDidCancel()
        }
        audioPlayer = nil
    }

    /// Pauses current speech (not fully supported for cloud TTS - stops instead)
    func pause() {
        audioPlayer?.pause()
    }

    /// Resumes paused speech
    func resume() {
        audioPlayer?.play()
    }

    // MARK: - Private Methods

    private func buildRequest(text: String, languageCode: String, speakingRate: Float) -> URLRequest? {
        let url = baseURL.appendingPathComponent("tts")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConfig.translationTimeout

        let body: [String: Any] = [
            "text": text,
            "languageCode": languageCode,
            "speakingRate": speakingRate,
            "deviceId": deviceId
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            return request
        } catch {
            #if DEBUG
            print("[CloudTTS] Failed to encode request: \(error)")
            #endif
            return nil
        }
    }

    private func playAudio(data: Data) {
        do {
            // Configure audio session for playback
            try configureAudioSession()

            // Create audio player
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            // Start playback
            if audioPlayer?.play() == true {
                isPlaying = true
                delegate?.textToSpeechDidStart()
                #if DEBUG
                print("[CloudTTS] Audio playback started")
                #endif
            } else {
                delegate?.textToSpeech(didFailWithError: .audioSessionError(NSError(domain: "CloudTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start playback"])))
            }

        } catch {
            #if DEBUG
            print("[CloudTTS] Audio playback error: \(error)")
            #endif
            delegate?.textToSpeech(didFailWithError: .audioSessionError(error))
        }
    }

    /// Maps rate from 0.0-1.0 (AVSpeechSynthesizer range) to 0.25-4.0 (Cloud TTS range)
    /// 0.5 maps to 1.0 (normal speed)
    private func mapRateToCloudTTS(_ rate: Float) -> Float {
        // AVSpeechSynthesizer uses 0.0-1.0 with 0.5 as default
        // Cloud TTS uses 0.25-4.0 with 1.0 as default
        // Linear mapping: rate 0.0 -> 0.25, rate 0.5 -> 1.0, rate 1.0 -> 4.0
        if rate <= 0.5 {
            // Map 0.0-0.5 to 0.25-1.0
            return 0.25 + (rate * 1.5)
        } else {
            // Map 0.5-1.0 to 1.0-4.0
            return 1.0 + ((rate - 0.5) * 6.0)
        }
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
        )
        try audioSession.setActive(true, options: [])
    }
}

// MARK: - AVAudioPlayerDelegate

extension CloudTTSService: AVAudioPlayerDelegate {

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        #if DEBUG
        print("[CloudTTS] Audio playback finished (success: \(flag))")
        #endif
        isPlaying = false
        delegate?.textToSpeechDidFinish()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        #if DEBUG
        print("[CloudTTS] Audio decode error: \(error?.localizedDescription ?? "unknown")")
        #endif
        isPlaying = false
        if let error = error {
            delegate?.textToSpeech(didFailWithError: .audioSessionError(error))
        }
    }
}
