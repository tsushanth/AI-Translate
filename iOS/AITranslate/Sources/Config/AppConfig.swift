import Foundation

/// Application configuration for environment-specific settings
enum AppConfig {

    // MARK: - API Configuration

    /// Base URL for the Cloud Run backend
    static var cloudRunBaseURL: URL {
        #if DEBUG
        // Development/staging endpoint (same as production for now)
        return URL(string: "https://ai-translate-backend-917362189743.us-central1.run.app")!
        #else
        // Production endpoint
        return URL(string: "https://ai-translate-backend-917362189743.us-central1.run.app")!
        #endif
    }

    /// API version path component
    static let apiVersion = "v1"

    /// Full base URL including API version
    static var apiBaseURL: URL {
        cloudRunBaseURL.appendingPathComponent(apiVersion)
    }

    // MARK: - Timeouts

    /// Default network request timeout in seconds
    static let requestTimeout: TimeInterval = 30.0

    /// Timeout for translation requests (may take longer for large texts)
    static let translationTimeout: TimeInterval = 60.0

    // MARK: - Device Identification

    /// Unique device identifier for anonymous usage tracking
    /// Persisted in UserDefaults for consistency across sessions
    static var deviceId: String {
        let key = "com.aitranslate.deviceId"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
