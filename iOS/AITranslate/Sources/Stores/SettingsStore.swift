import Foundation
import SwiftUI
import UIKit

/// Haptic feedback helper that respects user settings
enum HapticFeedback {
    private static var lightGenerator: UIImpactFeedbackGenerator?
    private static var mediumGenerator: UIImpactFeedbackGenerator?
    private static var heavyGenerator: UIImpactFeedbackGenerator?
    private static var notificationGenerator: UINotificationFeedbackGenerator?
    private static var selectionGenerator: UISelectionFeedbackGenerator?

    /// Triggers light impact feedback
    static func light() {
        guard SettingsStore.shared.hapticFeedback else { return }
        if lightGenerator == nil {
            lightGenerator = UIImpactFeedbackGenerator(style: .light)
        }
        lightGenerator?.impactOccurred()
    }

    /// Triggers medium impact feedback
    static func medium() {
        guard SettingsStore.shared.hapticFeedback else { return }
        if mediumGenerator == nil {
            mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
        }
        mediumGenerator?.impactOccurred()
    }

    /// Triggers heavy impact feedback
    static func heavy() {
        guard SettingsStore.shared.hapticFeedback else { return }
        if heavyGenerator == nil {
            heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        }
        heavyGenerator?.impactOccurred()
    }

    /// Triggers success notification feedback
    static func success() {
        guard SettingsStore.shared.hapticFeedback else { return }
        if notificationGenerator == nil {
            notificationGenerator = UINotificationFeedbackGenerator()
        }
        notificationGenerator?.notificationOccurred(.success)
    }

    /// Triggers warning notification feedback
    static func warning() {
        guard SettingsStore.shared.hapticFeedback else { return }
        if notificationGenerator == nil {
            notificationGenerator = UINotificationFeedbackGenerator()
        }
        notificationGenerator?.notificationOccurred(.warning)
    }

    /// Triggers error notification feedback
    static func error() {
        guard SettingsStore.shared.hapticFeedback else { return }
        if notificationGenerator == nil {
            notificationGenerator = UINotificationFeedbackGenerator()
        }
        notificationGenerator?.notificationOccurred(.error)
    }

    /// Triggers selection changed feedback
    static func selection() {
        guard SettingsStore.shared.hapticFeedback else { return }
        if selectionGenerator == nil {
            selectionGenerator = UISelectionFeedbackGenerator()
        }
        selectionGenerator?.selectionChanged()
    }
}

/// App color scheme preference
enum AppColorScheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Persistent settings storage using UserDefaults
@Observable
final class SettingsStore {

    // MARK: - Singleton

    static let shared = SettingsStore()

    // MARK: - Keys

    private enum Keys {
        static let translationProvider = "settings.translationProvider"
        static let autoDetectLanguage = "settings.autoDetectLanguage"
        static let hapticFeedback = "settings.hapticFeedback"
        static let appColorScheme = "settings.appColorScheme"
        static let languagePairUsage = "settings.languagePairUsage"
        static let cacheLimit = "settings.cacheLimit"
    }

    /// Cache size limit options
    enum CacheLimit: Int, CaseIterable {
        case entries50 = 50
        case entries100 = 100
        case entries200 = 200
        case entries500 = 500
        case unlimited = 0

        var displayName: String {
            switch self {
            case .entries50: return "50 entries"
            case .entries100: return "100 entries"
            case .entries200: return "200 entries"
            case .entries500: return "500 entries"
            case .unlimited: return "Unlimited"
            }
        }

        var maxEntries: Int {
            self == .unlimited ? Int.max : rawValue
        }
    }

    // MARK: - Properties

    /// Selected translation provider
    var translationProvider: TranslationProviderType {
        didSet {
            UserDefaults.standard.set(translationProvider.rawValue, forKey: Keys.translationProvider)
        }
    }

    /// Whether to auto-detect source language
    var autoDetectLanguage: Bool {
        didSet {
            UserDefaults.standard.set(autoDetectLanguage, forKey: Keys.autoDetectLanguage)
        }
    }

    /// Whether to use haptic feedback
    var hapticFeedback: Bool {
        didSet {
            UserDefaults.standard.set(hapticFeedback, forKey: Keys.hapticFeedback)
        }
    }

    /// App color scheme preference
    var appColorScheme: AppColorScheme {
        didSet {
            UserDefaults.standard.set(appColorScheme.rawValue, forKey: Keys.appColorScheme)
        }
    }

    /// Translation cache size limit
    var cacheLimit: CacheLimit {
        didSet {
            UserDefaults.standard.set(cacheLimit.rawValue, forKey: Keys.cacheLimit)
        }
    }

    // MARK: - Initialization

    private init() {
        // Load translation provider
        if let providerString = UserDefaults.standard.string(forKey: Keys.translationProvider),
           let provider = TranslationProviderType(rawValue: providerString) {
            self.translationProvider = provider
        } else {
            self.translationProvider = .google // Default
        }

        // Load color scheme (default to dark)
        if let schemeString = UserDefaults.standard.string(forKey: Keys.appColorScheme),
           let scheme = AppColorScheme(rawValue: schemeString) {
            self.appColorScheme = scheme
        } else {
            self.appColorScheme = .dark // Default to dark
        }

        // Load other settings
        self.autoDetectLanguage = UserDefaults.standard.object(forKey: Keys.autoDetectLanguage) as? Bool ?? true
        self.hapticFeedback = UserDefaults.standard.object(forKey: Keys.hapticFeedback) as? Bool ?? true

        // Load cache limit (default to 100 entries)
        if let cacheLimitValue = UserDefaults.standard.object(forKey: Keys.cacheLimit) as? Int,
           let limit = CacheLimit(rawValue: cacheLimitValue) {
            self.cacheLimit = limit
        } else {
            self.cacheLimit = .entries100 // Default
        }
    }

    // MARK: - Language Pair Usage Tracking

    /// Represents a language pair with usage count
    struct LanguagePairUsage: Codable, Hashable {
        let sourceLanguage: String
        let targetLanguage: String
        var usageCount: Int

        var pairKey: String {
            "\(sourceLanguage)->\(targetLanguage)"
        }
    }

    /// Records a translation for the given language pair
    func recordLanguagePairUsage(source: String, target: String) {
        var usage = loadLanguagePairUsage()

        // Find existing or create new
        if let index = usage.firstIndex(where: { $0.sourceLanguage == source && $0.targetLanguage == target }) {
            usage[index].usageCount += 1
        } else {
            usage.append(LanguagePairUsage(sourceLanguage: source, targetLanguage: target, usageCount: 1))
        }

        saveLanguagePairUsage(usage)
    }

    /// Returns the most frequently used language pairs
    func mostUsedLanguagePairs(limit: Int = 5) -> [LanguagePairUsage] {
        let usage = loadLanguagePairUsage()
        return Array(usage.sorted { $0.usageCount > $1.usageCount }.prefix(limit))
    }

    /// Returns language pairs that should be suggested for offline download
    /// (used more than 5 times and not yet downloaded)
    func suggestedLanguagePairsForOffline() -> [LanguagePairUsage] {
        let usage = loadLanguagePairUsage()
        return usage
            .filter { $0.usageCount >= 5 }
            .sorted { $0.usageCount > $1.usageCount }
    }

    private func loadLanguagePairUsage() -> [LanguagePairUsage] {
        guard let data = UserDefaults.standard.data(forKey: Keys.languagePairUsage) else {
            return []
        }
        return (try? JSONDecoder().decode([LanguagePairUsage].self, from: data)) ?? []
    }

    private func saveLanguagePairUsage(_ usage: [LanguagePairUsage]) {
        if let data = try? JSONEncoder().encode(usage) {
            UserDefaults.standard.set(data, forKey: Keys.languagePairUsage)
        }
    }
}
