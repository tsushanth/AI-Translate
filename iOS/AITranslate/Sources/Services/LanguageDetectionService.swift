import Foundation
import NaturalLanguage

/// Result of language detection
struct LanguageDetectionResult {
    /// The detected language code (e.g., "en", "es", "fr")
    let languageCode: String

    /// Confidence score (0.0 to 1.0)
    let confidence: Double

    /// All detected language hypotheses with their probabilities
    let alternatives: [(languageCode: String, probability: Double)]
}

/// Service for detecting the language of text using Apple's NaturalLanguage framework.
/// This works completely offline and is very fast.
final class LanguageDetectionService {

    // MARK: - Singleton

    static let shared = LanguageDetectionService()

    // MARK: - Private Properties

    private let recognizer = NLLanguageRecognizer()

    /// Minimum text length for reliable detection
    private let minimumTextLength = 10

    /// Minimum confidence threshold for detection
    private let minimumConfidence = 0.5

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Detects the language of the given text.
    /// - Parameter text: The text to analyze
    /// - Returns: The detected language code, or nil if detection failed
    func detectLanguage(_ text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return nil
        }

        recognizer.reset()
        recognizer.processString(trimmedText)

        guard let language = recognizer.dominantLanguage else {
            return nil
        }

        return language.rawValue
    }

    /// Detects the language with confidence score.
    /// - Parameter text: The text to analyze
    /// - Returns: LanguageDetectionResult with language code and confidence, or nil if detection failed
    func detectLanguageWithConfidence(_ text: String) -> LanguageDetectionResult? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return nil
        }

        recognizer.reset()
        recognizer.processString(trimmedText)

        // Get hypotheses with probabilities
        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)

        guard let dominantLanguage = recognizer.dominantLanguage,
              let confidence = hypotheses[dominantLanguage] else {
            return nil
        }

        // Convert hypotheses to array
        let alternatives = hypotheses.map { (languageCode: $0.key.rawValue, probability: $0.value) }
            .sorted { $0.probability > $1.probability }

        return LanguageDetectionResult(
            languageCode: dominantLanguage.rawValue,
            confidence: confidence,
            alternatives: alternatives
        )
    }

    /// Detects language only if text is long enough for reliable detection.
    /// Short text (under 10 characters) often leads to unreliable results.
    /// - Parameter text: The text to analyze
    /// - Returns: The detected language code, or nil if text is too short or detection failed
    func detectLanguageIfReliable(_ text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedText.count >= minimumTextLength else {
            #if DEBUG
            print("[LanguageDetection] Text too short for reliable detection: \(trimmedText.count) chars")
            #endif
            return nil
        }

        guard let result = detectLanguageWithConfidence(trimmedText) else {
            return nil
        }

        // Only return if confidence is above threshold
        if result.confidence >= minimumConfidence {
            #if DEBUG
            print("[LanguageDetection] Detected: \(result.languageCode) with confidence: \(String(format: "%.2f", result.confidence))")
            #endif
            return result.languageCode
        }

        #if DEBUG
        print("[LanguageDetection] Low confidence: \(String(format: "%.2f", result.confidence)) for \(result.languageCode)")
        #endif
        return nil
    }

    /// Checks if the text appears to be in the specified language.
    /// - Parameters:
    ///   - text: The text to analyze
    ///   - languageCode: The expected language code
    /// - Returns: True if the text appears to be in the specified language
    func isLanguage(_ text: String, languageCode: String) -> Bool {
        guard let detected = detectLanguage(text) else {
            return false
        }

        // Normalize codes for comparison (e.g., "en" matches "en-US")
        let detectedBase = detected.components(separatedBy: "-").first ?? detected
        let expectedBase = languageCode.components(separatedBy: "-").first ?? languageCode

        return detectedBase.lowercased() == expectedBase.lowercased()
    }

    /// Returns common languages well-supported by the detection system.
    /// NLLanguageRecognizer supports 50+ languages.
    static var supportedLanguages: [String] {
        return commonLanguages
    }
}

// MARK: - Supported Languages

extension LanguageDetectionService {
    /// Common languages that NLLanguageRecognizer supports well
    static let commonLanguages: [String] = [
        "en", "es", "fr", "de", "it", "pt",
        "ru", "ja", "ko", "zh-Hans", "zh-Hant",
        "ar", "hi", "nl", "pl", "tr", "uk", "vi",
        "th", "id", "sv", "da", "no", "fi",
        "el", "cs", "ro", "hu", "he", "fa"
    ]
}
