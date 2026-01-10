import Foundation
import Network
import AVFoundation

/// TTS Mode for the app
enum TTSMode: String, CaseIterable, Identifiable {
    case automatic = "automatic"    // Use cloud if Pro & online, device otherwise
    case cloudOnly = "cloud"        // Always use cloud (requires Pro)
    case deviceOnly = "device"      // Always use device TTS (works offline)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .cloudOnly: return "Cloud (Pro)"
        case .deviceOnly: return "Device"
        }
    }

    var description: String {
        switch self {
        case .automatic: return "Uses premium voices when online, device voices offline"
        case .cloudOnly: return "Always use premium AI voices (requires internet)"
        case .deviceOnly: return "Always use device voices (works offline)"
        }
    }
}

/// Unified TTS Manager that intelligently switches between cloud and device TTS
/// - Pro users: Get cloud TTS with natural AI voices when online
/// - Free users: Get device TTS (AVSpeechSynthesizer) which works offline
/// - Automatic fallback: If cloud fails, falls back to device TTS
@MainActor
@Observable
final class TTSManager: NSObject {

    static let shared = TTSManager()

    // MARK: - Observable State

    private(set) var isSpeaking: Bool = false
    private(set) var currentMode: TTSMode = .automatic
    private(set) var isOnline: Bool = true
    private(set) var lastUsedService: String = ""

    // MARK: - Private Properties

    private let cloudTTS: CloudTTSService
    private let deviceTTS: TextToSpeechService
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.sayitai.ttsmanager.network")

    private var currentService: TextToSpeechServiceProtocol?
    private var pendingText: String?
    private var pendingLanguage: String?
    private var pendingRate: Float?

    /// Whether the user has premium access (subscription OR active trial)
    private var hasPremiumAccess: Bool {
        PurchaseManager.shared.hasPremiumAccess
    }

    // MARK: - Delegate

    weak var delegate: TextToSpeechDelegate?

    // MARK: - Initialization

    private override init() {
        self.cloudTTS = CloudTTSService()
        self.deviceTTS = TextToSpeechService()
        super.init()

        // Set up delegates
        cloudTTS.delegate = self
        deviceTTS.delegate = self

        // Load saved mode
        if let savedMode = UserDefaults.standard.string(forKey: "ttsMode"),
           let mode = TTSMode(rawValue: savedMode) {
            currentMode = mode
        }

        // Start network monitoring
        startNetworkMonitoring()
    }

    // MARK: - Public Methods

    /// Speaks the given text using the appropriate TTS service
    /// - Parameters:
    ///   - text: Text to speak
    ///   - languageCode: BCP-47 language code (e.g., "en-US", "es-ES")
    ///   - rate: Speech rate (0.0-1.0, default 0.5)
    func speak(text: String, languageCode: String, rate: Float = 0.5) {
        #if DEBUG
        print("[TTSManager] speak() - mode: \(currentMode), hasPremiumAccess: \(hasPremiumAccess), isOnline: \(isOnline)")
        #endif

        // Stop any current speech
        stop()

        // Store pending request for fallback
        pendingText = text
        pendingLanguage = languageCode
        pendingRate = rate

        // Determine which service to use
        let service = selectService()
        currentService = service

        #if DEBUG
        print("[TTSManager] Using service: \(service is CloudTTSService ? "Cloud" : "Device")")
        #endif

        // Speak
        service.speak(text: text, languageCode: languageCode, rate: rate)
    }

    /// Stops any current speech
    func stop() {
        cloudTTS.stop()
        deviceTTS.stop()
        isSpeaking = false
        pendingText = nil
        pendingLanguage = nil
        pendingRate = nil
    }

    /// Pauses current speech
    func pause() {
        currentService?.pause()
    }

    /// Resumes paused speech
    func resume() {
        currentService?.resume()
    }

    /// Sets the TTS mode
    func setMode(_ mode: TTSMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "ttsMode")
    }

    /// Returns available modes based on subscription/trial status
    var availableModes: [TTSMode] {
        if hasPremiumAccess {
            return TTSMode.allCases
        } else {
            // Free users (no sub, no trial) can only use device TTS
            return [.deviceOnly]
        }
    }

    /// Returns whether cloud TTS is currently available
    var isCloudAvailable: Bool {
        hasPremiumAccess && isOnline
    }

    /// Returns whether device TTS is available for a language
    func isDeviceTTSAvailable(for languageCode: String) -> Bool {
        TextToSpeechService.isLanguageSupported(languageCode)
    }

    // MARK: - Private Methods

    private func selectService() -> TextToSpeechServiceProtocol {
        switch currentMode {
        case .automatic:
            // Use cloud if has premium access (subscription OR trial) and online
            if hasPremiumAccess && isOnline {
                let accessType = PurchaseManager.shared.isPremium ? "Premium" : "Trial"
                lastUsedService = "Cloud (\(accessType))"
                return cloudTTS
            } else {
                lastUsedService = "Device"
                return deviceTTS
            }

        case .cloudOnly:
            // Only use cloud if available, otherwise fallback
            if hasPremiumAccess && isOnline {
                lastUsedService = "Cloud"
                return cloudTTS
            } else {
                // Fallback to device if offline or no access
                lastUsedService = "Device (Fallback)"
                return deviceTTS
            }

        case .deviceOnly:
            lastUsedService = "Device"
            return deviceTTS
        }
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = isOnline
                #if DEBUG
                print("[TTSManager] Network status: \(isOnline ? "Online" : "Offline")")
                #endif
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func fallbackToDeviceTTS() {
        guard let text = pendingText,
              let language = pendingLanguage,
              let rate = pendingRate else {
            return
        }

        #if DEBUG
        print("[TTSManager] Falling back to device TTS")
        #endif

        lastUsedService = "Device (Fallback)"
        currentService = deviceTTS
        deviceTTS.speak(text: text, languageCode: language, rate: rate)
    }
}

// MARK: - TextToSpeechDelegate

extension TTSManager: TextToSpeechDelegate {

    func textToSpeechDidStart() {
        isSpeaking = true
        delegate?.textToSpeechDidStart()
    }

    func textToSpeechDidFinish() {
        isSpeaking = false
        pendingText = nil
        pendingLanguage = nil
        pendingRate = nil
        delegate?.textToSpeechDidFinish()
    }

    func textToSpeechDidCancel() {
        isSpeaking = false
        delegate?.textToSpeechDidCancel()
    }

    func textToSpeech(didFailWithError error: TextToSpeechError) {
        #if DEBUG
        print("[TTSManager] TTS error: \(error.localizedDescription)")
        #endif

        // If cloud TTS failed and we have pending request, try device TTS
        if currentService is CloudTTSService && pendingText != nil {
            fallbackToDeviceTTS()
        } else {
            isSpeaking = false
            delegate?.textToSpeech(didFailWithError: error)
        }
    }

    func textToSpeech(willSpeakRangeOfSpeechString range: NSRange) {
        delegate?.textToSpeech(willSpeakRangeOfSpeechString: range)
    }
}

// MARK: - Async Extension

extension TTSManager {

    /// Speaks text and waits for completion
    func speakAsync(text: String, languageCode: String, rate: Float = 0.5) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let asyncDelegate = AsyncTTSDelegate(continuation: continuation)
            self.delegate = asyncDelegate
            asyncDelegate.retainSelf = asyncDelegate

            self.speak(text: text, languageCode: languageCode, rate: rate)
        }
    }

    private class AsyncTTSDelegate: TextToSpeechDelegate {
        let continuation: CheckedContinuation<Void, Error>
        var retainSelf: AsyncTTSDelegate?

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
