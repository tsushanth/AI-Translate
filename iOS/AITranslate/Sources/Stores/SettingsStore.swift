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
    }
}
