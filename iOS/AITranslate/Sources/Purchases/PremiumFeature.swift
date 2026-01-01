import SwiftUI

/// Defines premium-only features and their limits for free users
enum PremiumFeature: String, CaseIterable {
    case unlimitedTranslations
    case voiceTranslation
    case textToSpeech
    case unlimitedFavorites
    case cloudSync
    case offlineMode

    /// Display name for the feature
    var displayName: String {
        switch self {
        case .unlimitedTranslations: return "Unlimited Translations"
        case .voiceTranslation: return "Voice Translation"
        case .textToSpeech: return "Text-to-Speech"
        case .unlimitedFavorites: return "Unlimited Favorites"
        case .cloudSync: return "Cloud Sync"
        case .offlineMode: return "Offline Mode"
        }
    }

    /// Description shown in upgrade prompts
    var upgradePrompt: String {
        switch self {
        case .unlimitedTranslations:
            return "Upgrade to Premium for unlimited translations"
        case .voiceTranslation:
            return "Upgrade to Premium for voice translation"
        case .textToSpeech:
            return "Upgrade to Premium for text-to-speech"
        case .unlimitedFavorites:
            return "Upgrade to Premium for unlimited favorites"
        case .cloudSync:
            return "Upgrade to Premium to sync across devices"
        case .offlineMode:
            return "Upgrade to Premium for offline translations"
        }
    }

    /// Icon for the feature
    var icon: String {
        switch self {
        case .unlimitedTranslations: return "infinity"
        case .voiceTranslation: return "waveform"
        case .textToSpeech: return "speaker.wave.3"
        case .unlimitedFavorites: return "star.fill"
        case .cloudSync: return "icloud"
        case .offlineMode: return "wifi.slash"
        }
    }
}

// MARK: - Free Tier Limits

/// Limits for free users
enum FreeTierLimits {
    /// Maximum translations per day for free users
    static let dailyTranslations = 10

    /// Maximum favorites for free users
    static let maxFavorites = 5

    /// Maximum history entries for free users
    static let maxHistory = 20

    /// Whether TTS is available for free users
    static let ttsEnabled = false

    /// Whether voice input is available for free users
    static let voiceInputEnabled = false
}

// MARK: - Usage Tracker

/// Tracks daily usage for free tier limits
@MainActor
final class UsageTracker: ObservableObject {

    // MARK: - Singleton

    static let shared = UsageTracker()

    // MARK: - Published State

    @Published private(set) var dailyTranslationCount: Int = 0
    @Published private(set) var lastResetDate: Date = Date()

    // MARK: - Storage Keys

    private let countKey = "com.aitranslate.usage.dailyCount"
    private let dateKey = "com.aitranslate.usage.lastReset"

    // MARK: - Initialization

    private init() {
        loadUsage()
        checkAndResetIfNeeded()
    }

    // MARK: - Public Methods

    /// Checks if user can perform a translation
    var canTranslate: Bool {
        PurchaseManager.shared.isPremium ||
        dailyTranslationCount < FreeTierLimits.dailyTranslations
    }

    /// Remaining translations for today
    var remainingTranslations: Int {
        max(0, FreeTierLimits.dailyTranslations - dailyTranslationCount)
    }

    /// Records a translation
    func recordTranslation() {
        checkAndResetIfNeeded()
        dailyTranslationCount += 1
        saveUsage()
    }

    /// Checks if a feature is available
    func isFeatureAvailable(_ feature: PremiumFeature) -> Bool {
        if PurchaseManager.shared.isPremium {
            return true
        }

        switch feature {
        case .unlimitedTranslations:
            return canTranslate
        case .voiceTranslation:
            return FreeTierLimits.voiceInputEnabled
        case .textToSpeech:
            return FreeTierLimits.ttsEnabled
        case .unlimitedFavorites:
            // Check current favorites count elsewhere
            return true
        case .cloudSync, .offlineMode:
            return false
        }
    }

    // MARK: - Private Methods

    private func checkAndResetIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastResetDate) {
            dailyTranslationCount = 0
            lastResetDate = Date()
            saveUsage()
        }
    }

    private func loadUsage() {
        dailyTranslationCount = UserDefaults.standard.integer(forKey: countKey)
        if let date = UserDefaults.standard.object(forKey: dateKey) as? Date {
            lastResetDate = date
        }
    }

    private func saveUsage() {
        UserDefaults.standard.set(dailyTranslationCount, forKey: countKey)
        UserDefaults.standard.set(lastResetDate, forKey: dateKey)
    }
}

// MARK: - Premium Gate View Modifier

/// View modifier that shows paywall when tapped if feature requires premium
struct PremiumGateModifier: ViewModifier {
    let feature: PremiumFeature
    let action: () -> Void

    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if purchaseManager.isPremium || UsageTracker.shared.isFeatureAvailable(feature) {
                    action()
                } else {
                    showPaywall = true
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
    }
}

extension View {
    /// Gates a view behind a premium feature check
    func premiumGate(feature: PremiumFeature, action: @escaping () -> Void) -> some View {
        modifier(PremiumGateModifier(feature: feature, action: action))
    }
}

// MARK: - Premium Badge

/// Badge indicating a feature requires premium
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption2)

            Text("PRO")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(4)
    }
}

// MARK: - Upgrade Prompt View

/// A prompt encouraging users to upgrade
struct UpgradePromptView: View {
    let feature: PremiumFeature
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            Text(feature.displayName)
                .font(.headline)

            Text(feature.upgradePrompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showPaywall = true
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Premium")
                }
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .padding()
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Translation Limit Banner

/// Banner showing remaining free translations
struct TranslationLimitBanner: View {
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @ObservedObject private var usageTracker = UsageTracker.shared

    @State private var showPaywall = false

    var body: some View {
        if !purchaseManager.isPremium {
            Button {
                showPaywall = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)

                    if usageTracker.remainingTranslations > 0 {
                        Text("\(usageTracker.remainingTranslations) free translations left today")
                    } else {
                        Text("Daily limit reached")
                    }

                    Spacer()

                    Text("Upgrade")
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Premium Badge") {
    PremiumBadge()
        .padding()
}

#Preview("Upgrade Prompt") {
    UpgradePromptView(feature: .voiceTranslation)
}

#Preview("Translation Limit Banner") {
    VStack {
        TranslationLimitBanner()
            .padding()
    }
}
#endif
