import SwiftUI
import StoreKit

/// Purchase result for UI feedback
enum PurchaseResult {
    case idle
    case processing
    case success
    case cancelled
    case error(String)
}

/// Paywall view specifically designed for onboarding flow
/// Uses a "hard paywall" approach like iTranslate - user must start trial or subscribe
struct OnboardingPaywallView: View {
    @ObservedObject var purchaseManager: PurchaseManager
    @Binding var selectedPlan: SubscriptionPlan?
    let onSubscribe: (SubscriptionPlan) -> Void
    let onSkip: () -> Void

    @State private var purchaseResult: PurchaseResult = .idle
    @State private var showSuccessOverlay: Bool = false
    @State private var showCloseButton: Bool = false

    /// Delay before showing close button (in seconds)
    private let closeButtonDelay: Double = 3.0

    /// Computed plans from StoreKit products
    private var plans: [SubscriptionPlan] {
        guard !purchaseManager.products.isEmpty else {
            return SubscriptionPlan.placeholderPlans
        }

        return purchaseManager.products.map { product in
            let isYearly = product.id.contains("yearly")
            return SubscriptionPlan(
                from: product,
                isBestValue: isYearly,
                savingsPercent: isYearly ? purchaseManager.yearlySavingsPercent : nil
            )
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top bar with delayed close button
                topBar

                ScrollView {
                    VStack(spacing: 24) {
                        // Premium badge
                        premiumBadge

                        // Headline
                        VStack(spacing: 12) {
                            Text("Unlock AI Translate Pro")
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            Text("Get unlimited translations, voice conversations, and camera scanning. Communicate confidently in any language.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 24)

                        // Feature checklist
                        featureChecklist
                            .padding(.horizontal, 20)

                        // Plan cards
                        planCardsSection
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                // Bottom action section (fixed)
                bottomActionSection
            }
            .disabled(showSuccessOverlay)

            // Success overlay
            if showSuccessOverlay {
                successOverlay
            }
        }
        .task {
            // Load products if not already loaded
            if purchaseManager.products.isEmpty {
                await purchaseManager.loadProducts()
            }
            // Select default plan (yearly)
            if selectedPlan == nil, let firstPlan = plans.first(where: { $0.isBestValue }) ?? plans.first {
                selectedPlan = firstPlan
            }
        }
        .task {
            // Show close button after delay (iTranslate-style hard paywall)
            try? await Task.sleep(nanoseconds: UInt64(closeButtonDelay * 1_000_000_000))
            withAnimation(.easeIn(duration: 0.3)) {
                showCloseButton = true
            }
        }
        .alert("Error", isPresented: $purchaseManager.showError) {
            Button("OK", role: .cancel) {
                purchaseResult = .idle
            }
        } message: {
            if let error = purchaseManager.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            // Close button (appears after delay)
            if showCloseButton {
                Button {
                    onSkip()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .transition(.opacity.combined(with: .scale))
                .accessibilityLabel("Close")
                .accessibilityHint("Continue with limited free version")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 44)
    }

    // MARK: - Premium Badge

    private var premiumBadge: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .blur(radius: 15)

            // Badge circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)

            // Icon
            Image(systemName: "crown.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Feature Checklist

    private var featureChecklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            FeatureCheckRow(text: "Unlimited text translations")
            FeatureCheckRow(text: "Real-time voice conversations")
            FeatureCheckRow(text: "Camera & image translation")
            FeatureCheckRow(text: "30+ languages supported")
            FeatureCheckRow(text: "Offline phrasebook access")
            FeatureCheckRow(text: "Ad-free experience")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Plan Cards Section

    @ViewBuilder
    private var planCardsSection: some View {
        if purchaseManager.isLoading {
            // Loading state
            VStack(spacing: 12) {
                PricingPlanSkeletonView()
                PricingPlanSkeletonView()
            }
        } else {
            // Show plans (real products if loaded, placeholders otherwise)
            VStack(spacing: 12) {
                ForEach(plans) { plan in
                    PricingPlanCardView(
                        plan: plan,
                        isSelected: selectedPlan?.id == plan.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPlan = plan
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottom Action Section

    private var bottomActionSection: some View {
        VStack(spacing: 16) {
            // Primary CTA - prominent trial button
            Button {
                Task {
                    await handlePurchase()
                }
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        if purchaseManager.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(ctaButtonTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    // Subtitle showing what happens after trial
                    if let plan = selectedPlan, plan.trialInfo != nil {
                        Text("then \(plan.price)/\(plan.period)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: selectedPlan != nil && !purchaseManager.isPurchasing
                                    ? [Color.blue, Color.blue.opacity(0.8)]
                                    : [Color.gray, Color.gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                )
            }
            .disabled(selectedPlan == nil || purchaseManager.isPurchasing)
            .padding(.horizontal, 20)
            .accessibilityHint(selectedPlan?.trialInfo != nil ? "Starts free trial, then charges after trial period" : "Starts paid subscription immediately")

            // No skip button - hard paywall (close X appears after delay instead)

            // Legal footer with disclosure and links
            SubscriptionLegalFooterView(
                selectedPlan: selectedPlan,
                onTermsTapped: { openURL(SubscriptionLegalText.termsOfServiceURL) },
                onPrivacyTapped: { openURL(SubscriptionLegalText.privacyPolicyURL) },
                onRestoreTapped: {
                    Task {
                        await handleRestore()
                    }
                },
                isDisabled: purchaseManager.isPurchasing
            )
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
    }

    // MARK: - Purchase Handler

    private func handlePurchase() async {
        guard let plan = selectedPlan, let product = plan.storeProduct else {
            #if DEBUG
            print("[Paywall] No valid plan/product selected")
            #endif
            // If no StoreKit product (placeholder), just complete onboarding
            if selectedPlan != nil {
                onSubscribe(selectedPlan!)
            }
            return
        }

        purchaseResult = .processing

        let success = await purchaseManager.purchase(product)

        if success {
            purchaseResult = .success
            // Show success overlay briefly before dismissing
            withAnimation(.easeInOut(duration: 0.3)) {
                showSuccessOverlay = true
            }
            // Auto-dismiss after showing success
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            onSubscribe(plan)
        } else if purchaseManager.showError {
            purchaseResult = .error(purchaseManager.errorMessage ?? "Purchase failed")
        } else {
            // User cancelled - reset to idle
            purchaseResult = .cancelled
            purchaseResult = .idle
        }
    }

    // MARK: - Restore Handler

    private func handleRestore() async {
        purchaseResult = .processing

        await purchaseManager.restorePurchases()

        if purchaseManager.isPremium {
            purchaseResult = .success
            withAnimation(.easeInOut(duration: 0.3)) {
                showSuccessOverlay = true
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            // Notify parent that subscription was restored
            if let plan = selectedPlan {
                onSubscribe(plan)
            } else {
                onSkip() // Fallback - just complete onboarding
            }
        } else {
            purchaseResult = .idle
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(.white)
                }
                .transition(.scale.combined(with: .opacity))

                VStack(spacing: 8) {
                    Text("Welcome to Pro!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("You now have access to all premium features")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
        }
        .transition(.opacity)
    }

    /// CTA button title based on selected plan
    private var ctaButtonTitle: String {
        if purchaseManager.isPurchasing {
            return "Processing..."
        }

        guard let plan = selectedPlan else {
            return "Select a Plan"
        }

        if let trialInfo = plan.trialInfo {
            // Emphasize the free trial like iTranslate
            return "Start \(trialInfo)"
        } else {
            return "Subscribe Now"
        }
    }

    // MARK: - Helpers

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Feature Check Row

struct FeatureCheckRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Subscription Legal Text

/// Contains all required legal text for App Store subscription compliance
enum SubscriptionLegalText {

    // MARK: - Auto-Renewal Explanation

    /// Full auto-renewal disclosure for plans with free trial
    static func trialDisclosure(trialPeriod: String, price: String, period: String) -> String {
        """
        This is an auto-renewable subscription. After your \(trialPeriod.lowercased()) ends, \
        your subscription will automatically renew at \(price)/\(period) and your Apple ID \
        account will be charged unless you cancel at least 24 hours before the end of the \
        trial period. Your subscription will automatically renew each \(period) until you \
        cancel. You can manage or cancel your subscription anytime in your Apple ID account \
        settings. Any unused portion of a free trial will be forfeited when you purchase a \
        subscription.
        """
    }

    /// Full auto-renewal disclosure for plans without free trial
    static func standardDisclosure(price: String, period: String) -> String {
        """
        This is an auto-renewable subscription. Payment will be charged to your Apple ID \
        account at confirmation of purchase. Your subscription will automatically renew at \
        \(price)/\(period) unless canceled at least 24 hours before the end of the current \
        period. Your Apple ID account will be charged for renewal within 24 hours prior to \
        the end of the current period. You can manage or cancel your subscription anytime \
        in your Apple ID account settings.
        """
    }

    /// Generic disclosure when no plan is selected
    static let genericDisclosure = """
        Select a plan to continue. All subscriptions are auto-renewable and will \
        automatically renew unless canceled at least 24 hours before the end of the \
        current period. You can manage or cancel your subscription anytime in your \
        Apple ID account settings.
        """

    // MARK: - Short Summaries (for limited space)

    /// Short version of trial disclosure
    static func shortTrialDisclosure(trialPeriod: String, price: String, period: String) -> String {
        "Free trial converts to \(price)/\(period) unless canceled 24 hours before trial ends."
    }

    /// Short version of standard disclosure
    static func shortStandardDisclosure(price: String, period: String) -> String {
        "Auto-renews at \(price)/\(period). Cancel anytime in Settings."
    }

    // MARK: - Legal Links

    /// Terms of Service URL
    static let termsOfServiceURL = "https://kreativekoala.llc/terms"

    /// Privacy Policy URL
    static let privacyPolicyURL = "https://kreativekoala.llc/privacy"

    /// EULA URL (if separate from Terms)
    static let eulaURL = "https://kreativekoala.llc/terms"

    // MARK: - Accessibility Labels

    static let termsAccessibilityLabel = "Terms of Service - opens in browser"
    static let privacyAccessibilityLabel = "Privacy Policy - opens in browser"
    static let restoreAccessibilityLabel = "Restore previous purchases"
}

// MARK: - Subscription Legal Footer View

/// Displays all required legal text with proper accessibility support
struct SubscriptionLegalFooterView: View {
    let selectedPlan: SubscriptionPlan?
    let onTermsTapped: () -> Void
    let onPrivacyTapped: () -> Void
    let onRestoreTapped: () -> Void
    let isDisabled: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Whether to use compact layout for accessibility sizes
    private var useCompactLayout: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        VStack(spacing: 12) {
            // Main disclosure text
            disclosureTextView
                .accessibilityElement(children: .combine)

            // Legal links
            legalLinksView
        }
    }

    // MARK: - Disclosure Text

    private var disclosureTextView: some View {
        Text(disclosureString)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(disclosureAccessibilityLabel)
    }

    private var disclosureString: String {
        guard let plan = selectedPlan else {
            return SubscriptionLegalText.genericDisclosure
        }

        if let trialInfo = plan.trialInfo {
            return SubscriptionLegalText.trialDisclosure(
                trialPeriod: trialInfo,
                price: plan.price,
                period: plan.period
            )
        } else {
            return SubscriptionLegalText.standardDisclosure(
                price: plan.price,
                period: plan.period
            )
        }
    }

    private var disclosureAccessibilityLabel: String {
        guard let plan = selectedPlan else {
            return "Select a plan to see subscription details."
        }

        if let trialInfo = plan.trialInfo {
            return "Free trial for \(trialInfo). After trial ends, subscription renews at \(plan.price) per \(plan.period) unless canceled 24 hours before trial ends. Manage subscription in Apple ID settings."
        } else {
            return "Subscription renews at \(plan.price) per \(plan.period) unless canceled 24 hours before renewal. Manage subscription in Apple ID settings."
        }
    }

    // MARK: - Legal Links

    private var legalLinksView: some View {
        Group {
            if useCompactLayout {
                // Stack vertically for large accessibility sizes
                VStack(spacing: 8) {
                    legalLinkButton(title: "Terms of Service", action: onTermsTapped)
                        .accessibilityLabel(SubscriptionLegalText.termsAccessibilityLabel)

                    legalLinkButton(title: "Privacy Policy", action: onPrivacyTapped)
                        .accessibilityLabel(SubscriptionLegalText.privacyAccessibilityLabel)

                    legalLinkButton(title: "Restore Purchases", action: onRestoreTapped)
                        .accessibilityLabel(SubscriptionLegalText.restoreAccessibilityLabel)
                }
            } else {
                // Horizontal layout for standard sizes
                HStack(spacing: 6) {
                    legalLinkButton(title: "Terms", action: onTermsTapped)
                        .accessibilityLabel(SubscriptionLegalText.termsAccessibilityLabel)

                    separator

                    legalLinkButton(title: "Privacy", action: onPrivacyTapped)
                        .accessibilityLabel(SubscriptionLegalText.privacyAccessibilityLabel)

                    separator

                    legalLinkButton(title: "Restore", action: onRestoreTapped)
                        .accessibilityLabel(SubscriptionLegalText.restoreAccessibilityLabel)
                }
            }
        }
        .disabled(isDisabled)
    }

    private func legalLinkButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
                .underline()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }

    private var separator: some View {
        Text("·")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Onboarding Paywall") {
    OnboardingPaywallView(
        purchaseManager: .shared,
        selectedPlan: .constant(SubscriptionPlan.defaultPlan),
        onSubscribe: { _ in },
        onSkip: {}
    )
}
#endif
