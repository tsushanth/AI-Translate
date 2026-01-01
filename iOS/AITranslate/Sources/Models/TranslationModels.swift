import Foundation

// MARK: - Translation Provider

/// Supported translation providers
enum TranslationProviderType: String, Codable, CaseIterable, Sendable {
    case google = "google"
    case deepl = "deepl"

    var displayName: String {
        switch self {
        case .google: return "Google Translate"
        case .deepl: return "DeepL"
        }
    }

    var description: String {
        switch self {
        case .google: return "Fast and reliable neural translation"
        case .deepl: return "High-quality translations with natural phrasing"
        }
    }
}

// MARK: - Request Models

/// Request body for POST /v1/translate
struct TranslateRequestBody: Encodable, Sendable {
    /// Text to translate (1-5000 characters)
    let text: String

    /// Source language code (ISO 639-1) or "auto" for detection
    let sourceLanguage: String

    /// Target language code (ISO 639-1)
    let targetLanguage: String

    /// Anonymous device identifier (UUID v4)
    let deviceId: String

    /// Translation provider to use
    let provider: String?

    /// Optional configuration
    let options: TranslateOptions?

    struct TranslateOptions: Encodable, Sendable {
        /// Content format: "text" (default) or "html"
        let format: String?
    }
}

// MARK: - Response Models

/// Wrapper for successful API responses
struct APISuccessResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
    let meta: ResponseMeta
}

/// Wrapper for error API responses
struct APIErrorResponse: Decodable {
    let success: Bool
    let error: APIError
    let meta: ResponseMeta

    struct APIError: Decodable {
        let code: String
        let message: String
        let details: ErrorDetails?
    }

    enum ErrorDetails: Decodable {
        case validation([ValidationErrorDetail])
        case generic([String: AnyCodable])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let validationErrors = try? container.decode([ValidationErrorDetail].self) {
                self = .validation(validationErrors)
            } else if let generic = try? container.decode([String: AnyCodable].self) {
                self = .generic(generic)
            } else {
                self = .generic([:])
            }
        }
    }

    struct ValidationErrorDetail: Decodable {
        let field: String
        let message: String
    }
}

/// Response metadata
struct ResponseMeta: Decodable, Sendable {
    /// Unique request identifier for debugging
    let requestId: String

    /// Server processing time in milliseconds
    let processingTimeMs: Int?
}

/// Translation response data
struct TranslateResponseData: Decodable, Sendable {
    /// Translated text
    let translatedText: String

    /// Source language (resolved if "auto" was requested)
    let sourceLanguage: String

    /// Target language
    let targetLanguage: String

    /// Detected language (if sourceLanguage was "auto")
    let detectedLanguage: String?

    /// Detection confidence (0-1, if detected)
    let confidence: Double?

    /// Character count of source text
    let characterCount: Int

    /// Translation provider used
    let provider: String?
}

// MARK: - Helper for generic JSON decoding

/// Type-erased Codable wrapper for arbitrary JSON values
struct AnyCodable: Codable, Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode value"
                )
            )
        }
    }
}
