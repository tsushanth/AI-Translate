import Foundation
import Combine
import Translation

/// Status of a model download
enum DownloadStatus: Equatable {
    case idle
    case downloading(progress: Double)
    case processing
    case completed
    case failed(error: String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    var isCompleted: Bool {
        self == .completed
    }
}

/// Manages downloading, storing, and accessing offline AI models
@Observable
final class OfflineModelManager {
    static let shared = OfflineModelManager()

    // MARK: - Published State

    private(set) var downloadedPackage: OfflineModelPackage?
    private(set) var downloadProgress: Double = 0.0
    private(set) var downloadStatus: DownloadStatus = .idle
    private(set) var currentlyDownloading: OfflineModelPackage?

    // MARK: - Private Properties

    private let fileManager = FileManager.default

    // MARK: - Initialization

    private init() {
        loadDownloadedState()
    }

    // MARK: - Public Methods

    /// Download an offline model package
    func downloadPackage(_ package: OfflineModelPackage) async throws {
        guard package != .none else { return }

        await MainActor.run {
            currentlyDownloading = package
            downloadStatus = .downloading(progress: 0)
            downloadProgress = 0
        }

        do {
            // Download Whisper model if package includes one
            if let whisperModel = package.whisperModel {
                let whisperKitSize = whisperModel.whisperKitModelSize

                #if DEBUG
                print("[OfflineModelManager] Downloading package: \(package.displayName)")
                print("[OfflineModelManager] Whisper model: \(whisperKitSize.rawValue)")
                #endif

                await MainActor.run {
                    downloadStatus = .downloading(progress: 0.1)
                    downloadProgress = 0.1
                }

                // Download Whisper model via WhisperKit
                try await WhisperKitTranscriber.shared.loadModel(whisperKitSize, download: true)

                await MainActor.run {
                    downloadStatus = .downloading(progress: 0.8)
                    downloadProgress = 0.8
                }
            }

            // If package includes Apple Translation, prompt user to download languages
            // Note: Apple Translation languages are managed by the system
            // Users download them via Settings > General > Language & Region > Translation Languages
            if package.includesAppleTranslation {
                #if DEBUG
                print("[OfflineModelManager] Package includes Apple Translation - languages managed by system")
                #endif
            }

            await MainActor.run {
                downloadStatus = .completed
                downloadProgress = 1.0
                currentlyDownloading = nil
                downloadedPackage = package
            }

            // Save state
            UserDefaults.standard.selectedOfflinePackage = package
            UserDefaults.standard.hasDownloadedModels = true

            #if DEBUG
            print("[OfflineModelManager] Package download completed: \(package.displayName)")
            #endif

        } catch {
            await MainActor.run {
                downloadStatus = .failed(error: error.localizedDescription)
                currentlyDownloading = nil
            }
            throw OfflineModelError.downloadFailed
        }
    }

    /// Delete all downloaded models
    func deleteAllModels() async throws {
        // Unload WhisperKit model
        await WhisperKitTranscriber.shared.unloadModel()

        // Clear state
        await MainActor.run {
            downloadedPackage = nil
            downloadStatus = .idle
            downloadProgress = 0
        }

        UserDefaults.standard.selectedOfflinePackage = nil
        UserDefaults.standard.hasDownloadedModels = false

        #if DEBUG
        print("[OfflineModelManager] All models deleted")
        #endif
    }

    /// Check if any Whisper model is ready for transcription
    func canRecognizeSpeechOffline() -> Bool {
        return WhisperKitTranscriber.shared.modelState.isLoaded
    }

    /// Check if offline translation is available
    /// For Essential/Standard: Only English translation (via Whisper)
    /// For Full Offline/Maximum Quality: Multi-language (via Apple Translation)
    func canTranslateOffline(to targetLanguage: String) -> Bool {
        guard canRecognizeSpeechOffline() else { return false }

        // Whisper can always translate to English
        if targetLanguage == "en" {
            return true
        }

        // For other languages, need Apple Translation (Full Offline or Maximum Quality package)
        guard let package = downloadedPackage, package.includesAppleTranslation else {
            return false
        }

        // Apple Translation availability is checked at runtime
        return true
    }

    /// Get the current package's capabilities description
    var currentCapabilities: String {
        guard let package = downloadedPackage else {
            return "No offline models downloaded"
        }

        switch package {
        case .essential:
            return "Speech recognition (basic) + English translation"
        case .standard:
            return "Speech recognition (good) + English translation"
        case .fullOffline:
            return "Speech recognition (good) + 20 language translation"
        case .maximumQuality:
            return "Speech recognition (best) + 20 language translation"
        case .none:
            return "No offline models downloaded"
        }
    }

    /// Get total estimated size of downloaded models
    func totalDownloadedSizeFormatted() -> String {
        guard let package = downloadedPackage else {
            return "0 MB"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: package.totalSizeBytes)
    }

    /// Cancel ongoing download
    func cancelDownload() {
        downloadStatus = .idle
        downloadProgress = 0
        currentlyDownloading = nil
    }

    // MARK: - Private Methods

    private func loadDownloadedState() {
        // Check if we have a saved package
        if let savedPackage = UserDefaults.standard.selectedOfflinePackage {
            // Verify Whisper is still loaded
            if WhisperKitTranscriber.shared.modelState.isLoaded {
                downloadedPackage = savedPackage
            } else {
                // Model was unloaded (app restart), clear state
                downloadedPackage = nil
                UserDefaults.standard.selectedOfflinePackage = nil
            }
        }
    }
}

// MARK: - WhisperModelSize Extension

extension WhisperModelSize {
    /// Convert to WhisperKit model size
    var whisperKitModelSize: WhisperKitTranscriber.ModelSize {
        switch self {
        case .tiny: return .tiny
        case .small: return .small
        case .medium: return .medium
        }
    }
}

// MARK: - Errors

enum OfflineModelError: LocalizedError {
    case downloadFailed
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Failed to download model. Please check your internet connection and try again."
        case .modelNotFound:
            return "Model not found"
        }
    }
}

// MARK: - UserDefaults Keys

extension UserDefaults {
    private enum Keys {
        static let selectedOfflinePackage = "selectedOfflinePackage"
        static let hasDownloadedModels = "hasDownloadedModels"
    }

    var selectedOfflinePackage: OfflineModelPackage? {
        get {
            guard let rawValue = string(forKey: Keys.selectedOfflinePackage) else { return nil }
            return OfflineModelPackage(rawValue: rawValue)
        }
        set {
            set(newValue?.rawValue, forKey: Keys.selectedOfflinePackage)
        }
    }

    var hasDownloadedModels: Bool {
        get { bool(forKey: Keys.hasDownloadedModels) }
        set { set(newValue, forKey: Keys.hasDownloadedModels) }
    }
}
