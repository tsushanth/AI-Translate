import Foundation
import Translation
import SwiftUI

/// Translation service using Apple's on-device Translation framework
/// Works offline when language pairs are downloaded via Settings > Apps > Translate
/// Note: iOS 18's Translation framework requires SwiftUI context for translation sessions
@available(iOS 18.0, *)
final class AppleTranslationService: TranslationService, @unchecked Sendable {

    // MARK: - Supported Languages

    /// Languages supported by Apple Translation framework
    /// Users must download these in Settings > Apps > Translate > Downloaded Languages
    static let supportedLanguageCodes: Set<String> = [
        "ar",   // Arabic
        "zh",   // Chinese (Simplified)
        "nl",   // Dutch
        "en",   // English
        "fr",   // French
        "de",   // German
        "hi",   // Hindi
        "id",   // Indonesian
        "it",   // Italian
        "ja",   // Japanese
        "ko",   // Korean
        "pl",   // Polish
        "pt",   // Portuguese
        "ru",   // Russian
        "es",   // Spanish
        "th",   // Thai
        "tr",   // Turkish
        "uk",   // Ukrainian
        "vi"    // Vietnamese
    ]

    // MARK: - Translation State

    /// Pending translation completion handler
    private var translationContinuation: CheckedContinuation<String, Error>?

    /// Configuration for the translation session
    private var currentConfiguration: TranslationSession.Configuration?

    // MARK: - Public Methods

    /// Check if a language pair is supported by Apple Translation
    static func isLanguagePairSupported(from source: String, to target: String) -> Bool {
        let sourceCode = normalizeLanguageCode(source)
        let targetCode = normalizeLanguageCode(target)
        return supportedLanguageCodes.contains(sourceCode) && supportedLanguageCodes.contains(targetCode)
    }

    /// Normalize language code to base code (e.g., "en-US" -> "en")
    private static func normalizeLanguageCode(_ code: String) -> String {
        // Handle codes like "en-US", "zh-Hans", etc.
        let parts = code.split(separator: "-")
        return String(parts.first ?? Substring(code)).lowercased()
    }

    // MARK: - TranslationService

    func translate(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> TranslationResult {
        let startTime = Date()

        // Normalize language codes
        let sourceCode = Self.normalizeLanguageCode(sourceLanguage)
        let targetCode = Self.normalizeLanguageCode(targetLanguage)

        #if DEBUG
        print("[AppleTranslation] Translating from \(sourceCode) to \(targetCode)")
        print("[AppleTranslation] Text: \(text)")
        #endif

        // Validate language support
        guard Self.supportedLanguageCodes.contains(sourceCode) else {
            throw TranslationError.validationError(
                message: "Source language '\(sourceLanguage)' is not supported for offline translation."
            )
        }

        guard Self.supportedLanguageCodes.contains(targetCode) else {
            throw TranslationError.validationError(
                message: "Target language '\(targetLanguage)' is not supported for offline translation."
            )
        }

        // Check availability
        let sourceLocale = Locale.Language(identifier: sourceCode)
        let targetLocale = Locale.Language(identifier: targetCode)

        let availability = LanguageAvailability()
        let status = await availability.status(from: sourceLocale, to: targetLocale)

        #if DEBUG
        print("[AppleTranslation] Language pair status: \(status)")
        #endif

        switch status {
        case .installed:
            // Languages are downloaded and ready
            break
        case .supported:
            // Languages are supported but not downloaded
            throw TranslationError.validationError(
                message: "Please download \(targetLanguage) in Settings > Apps > Translate for offline use."
            )
        case .unsupported:
            throw TranslationError.validationError(
                message: "This language pair is not supported for offline translation."
            )
        @unknown default:
            throw TranslationError.validationError(
                message: "Unable to determine language availability."
            )
        }

        // Use the synchronous translation approach available in iOS 18
        do {
            // Create configuration
            let configuration = TranslationSession.Configuration(
                source: sourceLocale,
                target: targetLocale
            )

            // Perform translation using the batch API which can work without SwiftUI view context
            let request = TranslationSession.Request(sourceText: text)

            // Use a wrapper to perform the translation
            let translatedText = try await performTranslation(
                text: text,
                sourceLocale: sourceLocale,
                targetLocale: targetLocale
            )

            let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)

            #if DEBUG
            print("[AppleTranslation] Result: \(translatedText)")
            print("[AppleTranslation] Processing time: \(processingTime)ms")
            #endif

            return TranslationResult(
                translatedText: translatedText,
                sourceLanguage: sourceCode,
                targetLanguage: targetCode,
                detectedLanguage: nil,
                confidence: nil,
                characterCount: text.count,
                requestId: UUID().uuidString,
                processingTimeMs: processingTime
            )

        } catch let error as TranslationError {
            throw error
        } catch {
            #if DEBUG
            print("[AppleTranslation] Error: \(error)")
            #endif

            // Check for specific Translation framework errors
            let nsError = error as NSError
            if nsError.domain == "com.apple.Translation" {
                switch nsError.code {
                case 1: // Language not available
                    throw TranslationError.validationError(
                        message: "Please download the required languages in Settings > Apps > Translate."
                    )
                default:
                    throw TranslationError.serverError(
                        code: "APPLE_TRANSLATION_ERROR",
                        message: "Translation failed: \(error.localizedDescription)",
                        requestId: UUID().uuidString
                    )
                }
            }

            throw TranslationError.unknown(underlying: error)
        }
    }

    /// Internal method to perform translation
    /// Note: Due to iOS 18 API limitations, this requires special handling
    private func performTranslation(
        text: String,
        sourceLocale: Locale.Language,
        targetLocale: Locale.Language
    ) async throws -> String {
        // The Translation framework in iOS 18 primarily works through SwiftUI view modifiers
        // For service-based usage, we need to use the lower-level approach

        // Unfortunately, the TranslationSession requires a SwiftUI context in iOS 18
        // As a workaround, we'll use a helper that creates a temporary SwiftUI context

        return try await TranslationHelper.shared.translate(
            text: text,
            from: sourceLocale,
            to: targetLocale
        )
    }
}

// MARK: - Translation Helper

/// Helper class to bridge SwiftUI-based Translation API to service-based usage
@available(iOS 18.0, *)
@MainActor
final class TranslationHelper: ObservableObject {
    static let shared = TranslationHelper()

    private var pendingContinuation: CheckedContinuation<String, Error>?
    private var pendingText: String?
    private var configuration: TranslationSession.Configuration?

    private init() {}

    /// Translate text using Apple's Translation framework
    func translate(
        text: String,
        from source: Locale.Language,
        to target: Locale.Language
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation
            self.pendingText = text
            self.configuration = TranslationSession.Configuration(source: source, target: target)

            // Trigger the translation by invalidating configuration
            // This will be picked up by any active TranslationHelperView
            NotificationCenter.default.post(
                name: .translationRequested,
                object: TranslationRequest(text: text, source: source, target: target)
            )
        }
    }

    /// Called by TranslationHelperView when translation completes
    func completeTranslation(with result: String) {
        pendingContinuation?.resume(returning: result)
        pendingContinuation = nil
        pendingText = nil
    }

    /// Called by TranslationHelperView when translation fails
    func failTranslation(with error: Error) {
        pendingContinuation?.resume(throwing: error)
        pendingContinuation = nil
        pendingText = nil
    }
}

/// Request object for translation
@available(iOS 18.0, *)
struct TranslationRequest {
    let text: String
    let source: Locale.Language
    let target: Locale.Language
}

extension Notification.Name {
    static let translationRequested = Notification.Name("translationRequested")
}

// MARK: - SwiftUI Helper View

/// A SwiftUI view that handles translation requests
/// This view should be added to the app's view hierarchy to enable translation
@available(iOS 18.0, *)
struct TranslationHelperView: View {
    @State private var configuration: TranslationSession.Configuration?
    @State private var textToTranslate: String = ""
    @State private var sourceLanguage: Locale.Language = .init(identifier: "en")
    @State private var targetLanguage: Locale.Language = .init(identifier: "es")

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(configuration) { session in
                guard !textToTranslate.isEmpty else { return }

                do {
                    let response = try await session.translate(textToTranslate)
                    await MainActor.run {
                        TranslationHelper.shared.completeTranslation(with: response.targetText)
                    }
                } catch {
                    await MainActor.run {
                        TranslationHelper.shared.failTranslation(with: error)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .translationRequested)) { notification in
                guard let request = notification.object as? TranslationRequest else { return }

                textToTranslate = request.text
                sourceLanguage = request.source
                targetLanguage = request.target

                // Trigger translation by setting/invalidating configuration
                configuration = TranslationSession.Configuration(
                    source: request.source,
                    target: request.target
                )
            }
    }
}

// MARK: - Availability Checking

@available(iOS 18.0, *)
extension AppleTranslationService {

    /// Check if offline translation is available for a language pair
    /// Returns true if both languages are downloaded
    static func isOfflineAvailable(from source: String, to target: String) async -> Bool {
        let sourceCode = normalizeLanguageCode(source)
        let targetCode = normalizeLanguageCode(target)

        guard supportedLanguageCodes.contains(sourceCode),
              supportedLanguageCodes.contains(targetCode) else {
            return false
        }

        let sourceLocale = Locale.Language(identifier: sourceCode)
        let targetLocale = Locale.Language(identifier: targetCode)

        let availability = LanguageAvailability()
        let status = await availability.status(from: sourceLocale, to: targetLocale)

        return status == .installed
    }

    /// Get list of installed language pairs
    static func getInstalledLanguages() async -> [(source: String, target: String)] {
        var installed: [(String, String)] = []

        let availability = LanguageAvailability()

        for source in supportedLanguageCodes {
            for target in supportedLanguageCodes where source != target {
                let sourceLocale = Locale.Language(identifier: source)
                let targetLocale = Locale.Language(identifier: target)

                let status = await availability.status(from: sourceLocale, to: targetLocale)
                if status == .installed {
                    installed.append((source, target))
                }
            }
        }

        return installed
    }
}
