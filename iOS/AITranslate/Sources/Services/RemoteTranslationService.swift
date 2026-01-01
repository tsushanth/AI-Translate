import Foundation

/// Remote translation service that calls the Cloud Run backend
final class RemoteTranslationService: TranslationService, @unchecked Sendable {

    // MARK: - Properties

    private let session: URLSession
    private let baseURL: URL
    private let deviceId: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    /// Creates a new remote translation service
    /// - Parameters:
    ///   - baseURL: Base URL for the Cloud Run backend (defaults to AppConfig)
    ///   - session: URLSession to use for requests (defaults to shared)
    ///   - deviceId: Device identifier for tracking (defaults to AppConfig)
    init(
        baseURL: URL = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        deviceId: String = AppConfig.deviceId
    ) {
        self.baseURL = baseURL
        self.session = session
        self.deviceId = deviceId

        self.encoder = JSONEncoder()
        // Note: Backend expects camelCase keys (sourceLanguage, targetLanguage, etc.)
        // Do NOT use .convertToSnakeCase

        self.decoder = JSONDecoder()
        // Note: Backend returns camelCase keys
        // Do NOT use .convertFromSnakeCase
    }

    // MARK: - TranslationService

    func translate(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> TranslationResult {
        // Validate input locally before making request
        try validateInput(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)

        // Build request
        let request = try buildRequest(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Parse response
        return try parseResponse(data: data, response: response)
    }

    // MARK: - Private Methods

    private func validateInput(text: String, sourceLanguage: String, targetLanguage: String) throws {
        guard !text.isEmpty else {
            throw TranslationError.validationError(message: "Text cannot be empty")
        }

        guard text.count <= 5000 else {
            throw TranslationError.validationError(
                message: "Text exceeds maximum length of 5000 characters"
            )
        }

        guard !targetLanguage.isEmpty else {
            throw TranslationError.validationError(message: "Target language is required")
        }

        guard sourceLanguage == "auto" || !sourceLanguage.isEmpty else {
            throw TranslationError.validationError(message: "Source language is required")
        }
    }

    private func buildRequest(
        text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("translate")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = AppConfig.translationTimeout

        // Get provider from settings
        let provider = SettingsStore.shared.translationProvider

        let body = TranslateRequestBody(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            deviceId: deviceId,
            provider: provider.rawValue,
            options: nil
        )

        request.httpBody = try encoder.encode(body)

        return request
    }

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw TranslationError.cancelled
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .dataNotAllowed:
                throw TranslationError.networkError(underlying: error)
            case .timedOut:
                throw TranslationError.networkError(underlying: error)
            default:
                throw TranslationError.networkError(underlying: error)
            }
        } catch {
            throw TranslationError.unknown(underlying: error)
        }
    }

    private func parseResponse(data: Data, response: URLResponse) throws -> TranslationResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.unknown(
                underlying: NSError(
                    domain: "TranslationService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
                )
            )
        }

        let statusCode = httpResponse.statusCode

        // Handle success response (2xx)
        if (200...299).contains(statusCode) {
            return try parseSuccessResponse(data: data)
        }

        // Handle error response
        throw try parseErrorResponse(data: data, statusCode: statusCode)
    }

    private func parseSuccessResponse(data: Data) throws -> TranslationResult {
        do {
            let response = try decoder.decode(
                APISuccessResponse<TranslateResponseData>.self,
                from: data
            )

            return TranslationResult(
                translatedText: response.data.translatedText,
                sourceLanguage: response.data.sourceLanguage,
                targetLanguage: response.data.targetLanguage,
                detectedLanguage: response.data.detectedLanguage,
                confidence: response.data.confidence,
                characterCount: response.data.characterCount,
                requestId: response.meta.requestId,
                processingTimeMs: response.meta.processingTimeMs
            )
        } catch {
            throw TranslationError.decodingError(underlying: error)
        }
    }

    private func parseErrorResponse(data: Data, statusCode: Int) throws -> TranslationError {
        // Try to parse structured error response
        if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
            return .serverError(
                code: errorResponse.error.code,
                message: errorResponse.error.message,
                requestId: errorResponse.meta.requestId
            )
        }

        // Fall back to generic HTTP error
        let message = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        return .httpError(statusCode: statusCode, message: message)
    }
}

// MARK: - Convenience Extensions

extension RemoteTranslationService {

    /// Translates text with automatic language detection
    /// - Parameters:
    ///   - text: Text to translate
    ///   - targetLanguage: Target language code
    /// - Returns: Translation result with detected source language
    func translateWithAutoDetect(
        text: String,
        to targetLanguage: String
    ) async throws -> TranslationResult {
        try await translate(text: text, from: "auto", to: targetLanguage)
    }
}
