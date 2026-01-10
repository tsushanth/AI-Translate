import SwiftUI
import StoreKit

/// Paywall screen showing premium benefits and subscription options
struct PaywallView: View {
    @ObservedObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?

    init(purchaseManager: PurchaseManager = .shared) {
        self.purchaseManager = purchaseManager
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Benefits list
                    benefitsSection

                    // Product options
                    if purchaseManager.isLoading {
                        loadingSection
                    } else if purchaseManager.products.isEmpty {
                        errorSection
                    } else {
                        productsSection
                    }

                    // Purchase button
                    purchaseButton

                    // Restore purchases
                    restoreButton

                    // Terms and privacy
                    legalSection
                }
                .padding()
            }
            .navigationTitle("Go Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Error", isPresented: $purchaseManager.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = purchaseManager.errorMessage {
                    Text(error)
                }
            }
            .task {
                if purchaseManager.products.isEmpty {
                    await purchaseManager.loadProducts()
                }
                // Select yearly by default
                selectedProduct = purchaseManager.yearlyProduct ?? purchaseManager.products.first
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon / Premium badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            Text("Unlock Premium")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Get unlimited translations and exclusive features")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BenefitRow(
                icon: "infinity",
                title: "Unlimited Translations",
                description: "Translate as much as you want, no daily limits"
            )

            BenefitRow(
                icon: "waveform",
                title: "Voice Translation",
                description: "Speak and translate in real-time"
            )

            BenefitRow(
                icon: "speaker.wave.3",
                title: "Text-to-Speech",
                description: "Hear translations in native pronunciation"
            )

            BenefitRow(
                icon: "star.fill",
                title: "Unlimited Favorites",
                description: "Save as many phrases as you need"
            )

            BenefitRow(
                icon: "icloud",
                title: "Cloud Sync",
                description: "Access your history across all devices"
            )

            BenefitRow(
                icon: "bolt.fill",
                title: "Priority Processing",
                description: "Faster translations with no queue"
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Products Section

    private var productsSection: some View {
        VStack(spacing: 12) {
            ForEach(purchaseManager.products, id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    savingsPercent: product.id.contains("yearly") ? purchaseManager.yearlySavingsPercent : nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProduct = product
                    }
                }
            }
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading subscription options...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 150)
    }

    // MARK: - Error Section

    private var errorSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Unable to load subscriptions")
                .font(.headline)

            Button("Try Again") {
                Task {
                    await purchaseManager.loadProducts()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(height: 150)
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task {
                let success = await purchaseManager.purchase(product)
                if success {
                    dismiss()
                }
            }
        } label: {
            HStack {
                if purchaseManager.isPurchasing {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 4)
                }

                Text(purchaseButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .cornerRadius(14)
        }
        .disabled(selectedProduct == nil || purchaseManager.isPurchasing)
        .opacity(selectedProduct == nil ? 0.6 : 1.0)
    }

    private var purchaseButtonTitle: String {
        if purchaseManager.isPurchasing {
            return "Processing..."
        }

        guard let product = selectedProduct else {
            return "Select a Plan"
        }

        return "Subscribe for \(product.displayPrice)/\(product.subscriptionPeriodText)"
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            Task {
                await purchaseManager.restorePurchases()
                if purchaseManager.isPremium {
                    dismiss()
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .disabled(purchaseManager.isPurchasing)
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage subscriptions in Settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Terms of Service") {
                    // Open terms URL
                    if let url = URL(string: "https://kreativekoala.llc/terms") {
                        UIApplication.shared.open(url)
                    }
                }

                Text("•")
                    .foregroundStyle(.tertiary)

                Button("Privacy Policy") {
                    // Open privacy URL
                    if let url = URL(string: "https://kreativekoala.llc/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let savingsPercent: Int?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .purple : .secondary)

                // Product info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)

                        if let savings = savingsPercent, savings > 0 {
                            Text("Save \(savings)%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline)

                    Text("per \(product.subscriptionPeriodText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Product Extensions

extension Product {
    /// Returns a human-readable subscription period
    var subscriptionPeriodText: String {
        guard let subscription = subscription else { return "" }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        switch unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return ""
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Paywall") {
    PaywallView()
}
#endif
