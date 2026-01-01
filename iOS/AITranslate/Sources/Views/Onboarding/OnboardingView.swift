import SwiftUI
import StoreKit

/// Main onboarding flow view with swipeable pages
struct OnboardingView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var currentPage: Int = 0
    @State private var selectedPlan: SubscriptionPlan?
    @Environment(\.dismiss) private var dismiss

    /// Callback when onboarding is completed (subscribed or skipped)
    let onComplete: () -> Void

    /// Total number of pages (value props + pricing)
    private let totalPages = OnboardingPage.pages.count + 1

    /// Whether currently on the pricing page
    private var isOnPricingPage: Bool {
        currentPage == OnboardingPage.pages.count
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with skip button (hidden on pricing page - paywall has its own)
                if !isOnPricingPage {
                    topBar
                }

                // Page content
                TabView(selection: $currentPage) {
                    // Value proposition pages
                    ForEach(OnboardingPage.pages) { page in
                        OnboardingCardView(page: page)
                            .tag(page.id)
                    }

                    // Pricing page (last page) - uses hard paywall with delayed close button
                    OnboardingPaywallView(
                        purchaseManager: purchaseManager,
                        selectedPlan: $selectedPlan,
                        onSubscribe: handleSubscribe,
                        onSkip: handleSkip
                    )
                    .tag(OnboardingPage.pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom section (page indicator + CTA for value pages)
                if !isOnPricingPage {
                    bottomSection
                }
            }
        }
        .onChange(of: purchaseManager.isPremium) { _, isPremium in
            // If user became premium (from restore or purchase), complete onboarding
            if isPremium {
                completeOnboarding()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            // Skip button (only show on value prop pages)
            if !isOnPricingPage {
                Button("Skip") {
                    withAnimation {
                        currentPage = OnboardingPage.pages.count
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(height: 44)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Page indicator
            pageIndicator

            // Continue button
            Button {
                withAnimation {
                    if currentPage < totalPages - 1 {
                        currentPage += 1
                    }
                }
            } label: {
                Text(currentPage == OnboardingPage.pages.count - 1 ? "Continue" : "Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.blue)
                    )
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 32)
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }

    // MARK: - Actions

    private func handleSubscribe(_ plan: SubscriptionPlan) {
        #if DEBUG
        print("[Onboarding] Subscription completed for plan: \(plan.name)")
        #endif

        // Purchase is already handled by OnboardingPaywallView
        // This callback is triggered after successful purchase or restore
        completeOnboarding()
    }

    private func handleSkip() {
        #if DEBUG
        print("[Onboarding] Skipped - continuing with limited version")
        #endif

        completeOnboarding()
    }

    private func completeOnboarding() {
        // Mark onboarding as completed
        OnboardingManager.shared.markOnboardingCompleted()

        // Call completion handler
        onComplete()
    }
}

// MARK: - Onboarding Manager

/// Manages onboarding state persistence
final class OnboardingManager {
    static let shared = OnboardingManager()

    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    private init() {}

    /// Whether the user has completed onboarding
    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }

    /// Marks onboarding as completed
    func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
    }

    /// Resets onboarding state (for testing)
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: hasCompletedOnboardingKey)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Onboarding Flow") {
    OnboardingView(onComplete: {})
}

#Preview("Onboarding - Dark Mode") {
    OnboardingView(onComplete: {})
        .preferredColorScheme(.dark)
}
#endif
