import Foundation

/// Protocol defining the translation service interface
/// Allows for different implementations (remote, mock, cached)
protocol TranslationService: Sendable {

    /// Translates text from source language to target language
    /// - Parameters:
    ///   - text: The text to translate (1-5000 characters)
    ///   - sourceLanguage: Source language code (ISO 639-1) or "auto" for detection
    ///   - targetLanguage: Target language code (ISO 639-1)
    /// - Returns: Translation result containing translated text and metadata
    /// - Throws: TranslationError if the translation fails
    func translate(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> TranslationResult
}

/// Result of a successful translation
struct TranslationResult: Sendable, Equatable {
    /// The translated text
    let translatedText: String

    /// Source language code (resolved if "auto" was used)
    let sourceLanguage: String

    /// Target language code
    let targetLanguage: String

    /// Detected language code (if source was "auto")
    let detectedLanguage: String?

    /// Detection confidence (0-1, if language was detected)
    let confidence: Double?

    /// Character count of the source text
    let characterCount: Int

    /// Server request ID for debugging/support
    let requestId: String

    /// Server processing time in milliseconds
    let processingTimeMs: Int?
}

/// Errors that can occur during translation
enum TranslationError: LocalizedError, Sendable {
    /// Network connectivity issue
    case networkError(underlying: Error)

    /// Server returned an error HTTP status code
    case httpError(statusCode: Int, message: String?)

    /// Failed to decode the server response
    case decodingError(underlying: Error)

    /// Server returned a business logic error
    case serverError(code: String, message: String, requestId: String)

    /// Request validation failed locally
    case validationError(message: String)

    /// Request was cancelled
    case cancelled

    /// Unknown error
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Unable to connect to the translation service. Please check your internet connection."
        case .httpError(let statusCode, let message):
            if let message = message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (HTTP \(statusCode))"
        case .decodingError:
            return "Failed to process the server response."
        case .serverError(_, let message, _):
            return message
        case .validationError(let message):
            return message
        case .cancelled:
            return "Translation was cancelled."
        case .unknown:
            return "An unexpected error occurred."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Try again when you have a stable connection."
        case .httpError(let statusCode, _):
            if statusCode >= 500 {
                return "The server is temporarily unavailable. Please try again later."
            }
            return nil
        case .serverError(let code, _, _):
            if code == "RATE_LIMITED" {
                return "You've made too many requests. Please wait a moment before trying again."
            }
            return nil
        default:
            return nil
        }
    }
}
