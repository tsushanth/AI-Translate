import Foundation
import AVFoundation
import WhisperKit

/// Delegate protocol for WhisperKit transcription events
protocol WhisperKitTranscriberDelegate: AnyObject {
    func transcriber(didRecognize text: String, isFinal: Bool)
    func transcriber(didFailWithError error: WhisperKitError)
    func transcriberDidStart()
    func transcriberDidStop()
    func transcriber(didUpdateModelState state: WhisperKitTranscriber.ModelState)
}

/// Errors specific to WhisperKit transcription
enum WhisperKitError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case audioSetupFailed(Error)
    case transcriptionFailed(Error)
    case deviceNotSupported
    case alreadyRecording
    case notRecording
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded. Please download the model first."
        case .modelLoadFailed(let error):
            return "Failed to load Whisper model: \(error.localizedDescription)"
        case .audioSetupFailed(let error):
            return "Failed to setup audio: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .deviceNotSupported:
            return "This device does not support on-device speech recognition."
        case .alreadyRecording:
            return "Already recording."
        case .notRecording:
            return "Not currently recording."
        case .permissionDenied:
            return "Microphone permission denied."
        }
    }
}

/// WhisperKit-based transcription service for offline speech recognition
@Observable
final class WhisperKitTranscriber {

    // MARK: - Types

    enum ModelState: Equatable {
        case notLoaded
        case loading(progress: Double)
        case loaded
        case failed(String)

        var isLoaded: Bool {
            if case .loaded = self { return true }
            return false
        }
    }

    /// Available Whisper model sizes
    enum ModelSize: String, CaseIterable {
        case tiny = "openai_whisper-tiny"
        case base = "openai_whisper-base"
        case small = "openai_whisper-small"
        case medium = "openai_whisper-medium"

        var displayName: String {
            switch self {
            case .tiny: return "Tiny (~75 MB)"
            case .base: return "Base (~150 MB)"
            case .small: return "Small (~500 MB)"
            case .medium: return "Medium (~1.5 GB)"
            }
        }

        var estimatedSizeBytes: Int64 {
            switch self {
            case .tiny: return 75_000_000
            case .base: return 150_000_000
            case .small: return 500_000_000
            case .medium: return 1_500_000_000
            }
        }
    }

    // MARK: - Singleton

    static let shared = WhisperKitTranscriber()

    // MARK: - Properties

    weak var delegate: WhisperKitTranscriberDelegate?

    private(set) var modelState: ModelState = .notLoaded {
        didSet {
            delegate?.transcriber(didUpdateModelState: modelState)
        }
    }

    private(set) var isRecording = false
    private(set) var currentModelSize: ModelSize?

    // MARK: - Private Properties

    private var whisperKit: WhisperKit?
    private var audioEngine: AVAudioEngine?
    private var audioBuffers: [Float] = []
    private var recordingTask: Task<Void, Never>?

    /// Timer for detecting silence
    private var silenceTimer: Timer?
    private var lastTranscriptionTime: Date?
    private var lastTranscriptionText: String = ""
    private let silenceTimeout: TimeInterval = 2.0

    // MARK: - Initialization

    private init() {}

    // MARK: - Model Management

    /// Check if WhisperKit is supported on this device
    var isDeviceSupported: Bool {
        // WhisperKit requires iOS 17+ and Apple Silicon
        if #available(iOS 17, *) {
            return true
        }
        return false
    }

    /// Load a Whisper model
    /// - Parameter modelSize: The model size to load
    /// - Parameter download: Whether to download if not available locally
    func loadModel(_ modelSize: ModelSize, download: Bool = true) async throws {
        guard isDeviceSupported else {
            throw WhisperKitError.deviceNotSupported
        }

        // Unload existing model
        await unloadModel()

        modelState = .loading(progress: 0)

        do {
            #if DEBUG
            print("[WhisperKit] Loading model: \(modelSize.rawValue)")
            #endif

            // Initialize WhisperKit with the specified model
            // WhisperKit will automatically download from HuggingFace if needed
            let config = WhisperKitConfig(
                model: modelSize.rawValue,
                verbose: false,
                prewarm: true,
                load: true,
                download: download
            )

            whisperKit = try await WhisperKit(config)

            currentModelSize = modelSize
            modelState = .loaded

            #if DEBUG
            print("[WhisperKit] Model loaded successfully")
            #endif

        } catch {
            modelState = .failed(error.localizedDescription)
            throw WhisperKitError.modelLoadFailed(error)
        }
    }

    /// Unload the current model to free memory
    func unloadModel() async {
        whisperKit = nil
        currentModelSize = nil
        modelState = .notLoaded

        #if DEBUG
        print("[WhisperKit] Model unloaded")
        #endif
    }

    /// Check if a model is available locally
    func isModelAvailable(_ modelSize: ModelSize) async -> Bool {
        // Check if model files exist in WhisperKit's cache directory
        let fileManager = FileManager.default
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return false
        }

        let modelDir = cacheDir.appendingPathComponent("huggingface/models/argmaxinc/\(modelSize.rawValue)")
        return fileManager.fileExists(atPath: modelDir.path)
    }

    // MARK: - Transcription

    /// Start recording and transcribing
    /// - Parameter language: Optional language code (e.g., "en", "es"). If nil, auto-detects.
    func startRecording(language: String? = nil) async throws {
        guard !isRecording else {
            throw WhisperKitError.alreadyRecording
        }

        guard modelState.isLoaded, whisperKit != nil else {
            throw WhisperKitError.modelNotLoaded
        }

        // Check microphone permission
        let audioSession = AVAudioSession.sharedInstance()
        guard audioSession.recordPermission == .granted else {
            throw WhisperKitError.permissionDenied
        }

        // Setup audio session
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw WhisperKitError.audioSetupFailed(error)
        }

        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw WhisperKitError.audioSetupFailed(
                NSError(domain: "WhisperKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
            )
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Clear previous audio
        audioBuffers.removeAll()
        lastTranscriptionText = ""
        lastTranscriptionTime = Date()

        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        // Start audio engine
        do {
            try audioEngine.start()
            isRecording = true

            #if DEBUG
            print("[WhisperKit] Recording started")
            #endif

            await MainActor.run {
                delegate?.transcriberDidStart()
            }

            // Start periodic transcription
            startPeriodicTranscription(language: language)

        } catch {
            cleanup()
            throw WhisperKitError.audioSetupFailed(error)
        }
    }

    /// Stop recording
    func stopRecording() {
        guard isRecording else { return }

        #if DEBUG
        print("[WhisperKit] Stopping recording")
        #endif

        recordingTask?.cancel()
        recordingTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil

        // Final transcription with remaining audio
        if !audioBuffers.isEmpty, let whisperKit = whisperKit {
            Task {
                await performFinalTranscription(whisperKit: whisperKit)
            }
        }

        cleanup()

        Task { @MainActor in
            delegate?.transcriberDidStop()
        }
    }

    // MARK: - Private Methods

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Append samples to buffer
        audioBuffers.append(contentsOf: samples)
    }

    private func startPeriodicTranscription(language: String?) {
        recordingTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled && self.isRecording {
                // Wait a bit before transcribing
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                guard let whisperKit = self.whisperKit, !self.audioBuffers.isEmpty else {
                    continue
                }

                await self.performTranscription(whisperKit: whisperKit, language: language)
            }
        }
    }

    private func performTranscription(whisperKit: WhisperKit, language: String?) async {
        let samples = audioBuffers

        do {
            // Configure transcription options
            var options = DecodingOptions()
            options.language = language
            options.task = .transcribe
            options.withoutTimestamps = true

            // Perform transcription
            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)

            guard let result = results.first else { return }

            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty && text != lastTranscriptionText {
                lastTranscriptionText = text
                lastTranscriptionTime = Date()

                #if DEBUG
                print("[WhisperKit] Transcription: \(text)")
                #endif

                await MainActor.run { [weak self] in
                    self?.delegate?.transcriber(didRecognize: text, isFinal: false)
                }
            }

        } catch {
            #if DEBUG
            print("[WhisperKit] Transcription error: \(error)")
            #endif
        }
    }

    private func performFinalTranscription(whisperKit: WhisperKit) async {
        let samples = audioBuffers

        do {
            var options = DecodingOptions()
            options.task = .transcribe
            options.withoutTimestamps = true

            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)

            guard let result = results.first else { return }

            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                #if DEBUG
                print("[WhisperKit] Final transcription: \(text)")
                #endif

                await MainActor.run { [weak self] in
                    self?.delegate?.transcriber(didRecognize: text, isFinal: true)
                }
            }

        } catch {
            #if DEBUG
            print("[WhisperKit] Final transcription error: \(error)")
            #endif
        }
    }

    private func cleanup() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        isRecording = false
        audioBuffers.removeAll()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
