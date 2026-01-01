import Foundation
import StoreKit
import SwiftUI

/// Product identifiers for subscriptions
enum ProductID: String, CaseIterable {
    case monthlyPremium = "com.kreativekoala.aitranslate.monthly"
    case yearlyPremium = "com.kreativekoala.aitranslate.yearly"

    var displayName: String {
        switch self {
        case .monthlyPremium: return "Monthly"
        case .yearlyPremium: return "Yearly"
        }
    }
}

/// Manages in-app purchases using StoreKit 2
@MainActor
final class PurchaseManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PurchaseManager()

    // MARK: - Persistence Keys

    private enum StorageKey {
        static let isPremium = "isPremiumUser"
        static let subscriptionProductId = "subscriptionProductId"
        static let subscriptionExpirationDate = "subscriptionExpirationDate"
    }

    // MARK: - Published State

    /// Whether the user has an active premium subscription
    @Published private(set) var isPremium: Bool = false {
        didSet {
            // Persist premium status locally
            UserDefaults.standard.set(isPremium, forKey: StorageKey.isPremium)
        }
    }

    /// Available products for purchase
    @Published private(set) var products: [Product] = []

    /// Current subscription status
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown

    /// Whether a purchase is in progress
    @Published private(set) var isPurchasing: Bool = false

    /// Whether products are loading
    @Published private(set) var isLoading: Bool = false

    /// Error message for display
    @Published var errorMessage: String?

    /// Whether to show error alert
    @Published var showError: Bool = false

    // MARK: - Subscription Status

    enum SubscriptionStatus: Equatable {
        case unknown
        case notSubscribed
        case subscribed(expirationDate: Date?, productId: String)
        case expired(expirationDate: Date)
        case inGracePeriod(expirationDate: Date)
        case inBillingRetry

        var isActive: Bool {
            switch self {
            case .subscribed, .inGracePeriod, .inBillingRetry:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Private Properties

    private var transactionListener: Task<Void, Error>?
    private let productIDs = Set(ProductID.allCases.map(\.rawValue))

    // MARK: - Initialization

    private init() {
        // Load cached premium status first (for immediate UI state)
        isPremium = UserDefaults.standard.bool(forKey: StorageKey.isPremium)

        // Start listening for transactions
        transactionListener = listenForTransactions()

        // Load initial state and verify with App Store
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    /// Loads available products from the App Store
    func loadProducts() async {
        isLoading = true

        do {
            let storeProducts = try await Product.products(for: productIDs)

            // Sort: yearly first (usually better value), then monthly
            products = storeProducts.sorted { p1, p2 in
                if p1.id.contains("yearly") { return true }
                if p2.id.contains("yearly") { return false }
                return p1.price < p2.price
            }

        } catch {
            handleError("Failed to load products: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Purchase

    /// Purchases a product
    /// - Parameter product: The product to purchase
    /// - Returns: Whether the purchase was successful
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus()

                // Finish the transaction
                await transaction.finish()

                isPurchasing = false
                return true

            case .userCancelled:
                // User cancelled - not an error
                isPurchasing = false
                return false

            case .pending:
                // Transaction pending (e.g., Ask to Buy)
                handleError("Purchase is pending approval.")
                isPurchasing = false
                return false

            @unknown default:
                handleError("Unknown purchase result.")
                isPurchasing = false
                return false
            }

        } catch StoreKitError.userCancelled {
            // User cancelled - not an error
            isPurchasing = false
            return false

        } catch {
            handleError("Purchase failed: \(error.localizedDescription)")
            isPurchasing = false
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restores previous purchases
    func restorePurchases() async {
        isPurchasing = true

        do {
            // Sync with App Store
            try await AppStore.sync()

            // Update subscription status
            await updateSubscriptionStatus()

            if !isPremium {
                handleError("No active subscriptions found.")
            }

        } catch {
            handleError("Restore failed: \(error.localizedDescription)")
        }

        isPurchasing = false
    }

    // MARK: - Subscription Status

    /// Updates the current subscription status
    func updateSubscriptionStatus() async {
        // Check for active subscription
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if this is one of our subscription products
                guard productIDs.contains(transaction.productID) else { continue }

                // Check subscription status
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        // Active subscription
                        subscriptionStatus = .subscribed(
                            expirationDate: expirationDate,
                            productId: transaction.productID
                        )
                        isPremium = true
                        // Persist subscription details
                        UserDefaults.standard.set(transaction.productID, forKey: StorageKey.subscriptionProductId)
                        UserDefaults.standard.set(expirationDate, forKey: StorageKey.subscriptionExpirationDate)
                        return
                    } else {
                        // Check for grace period or billing retry
                        if let renewalInfo = await getRenewalInfo(for: transaction.productID) {
                            if renewalInfo.isInBillingRetry {
                                subscriptionStatus = .inBillingRetry
                                isPremium = true
                                return
                            }
                            if let gracePeriodExpiration = renewalInfo.gracePeriodExpirationDate,
                               gracePeriodExpiration > Date() {
                                subscriptionStatus = .inGracePeriod(expirationDate: gracePeriodExpiration)
                                isPremium = true
                                return
                            }
                        }

                        // Expired
                        subscriptionStatus = .expired(expirationDate: expirationDate)
                    }
                }

            } catch {
                // Verification failed - skip this transaction
                continue
            }
        }

        // No active subscription found
        subscriptionStatus = .notSubscribed
        isPremium = false
        // Clear persisted subscription details
        UserDefaults.standard.removeObject(forKey: StorageKey.subscriptionProductId)
        UserDefaults.standard.removeObject(forKey: StorageKey.subscriptionExpirationDate)
    }

    // MARK: - Transaction Listener

    /// Listens for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try await self?.checkVerified(result)

                    // Update status on main actor
                    await self?.updateSubscriptionStatus()

                    // Finish the transaction
                    await transaction?.finish()

                } catch {
                    // Verification failed
                    print("[PurchaseManager] Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    /// Verifies a transaction result
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }

    /// Gets renewal info for a subscription
    private func getRenewalInfo(for productID: String) async -> Product.SubscriptionInfo.RenewalInfo? {
        guard let product = products.first(where: { $0.id == productID }),
              let subscription = product.subscription else {
            return nil
        }

        do {
            let statuses = try await subscription.status
            for status in statuses {
                if case .verified(let renewalInfo) = status.renewalInfo {
                    return renewalInfo
                }
            }
        } catch {
            print("[PurchaseManager] Failed to get renewal info: \(error)")
        }

        return nil
    }

    /// Handles errors
    private func handleError(_ message: String) {
        errorMessage = message
        showError = true

        #if DEBUG
        print("[PurchaseManager] Error: \(message)")
        #endif
    }

    // MARK: - Product Helpers

    /// Gets the monthly product
    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthlyPremium.rawValue }
    }

    /// Gets the yearly product
    var yearlyProduct: Product? {
        products.first { $0.id == ProductID.yearlyPremium.rawValue }
    }

    /// Calculates the savings percentage for yearly vs monthly
    var yearlySavingsPercent: Int? {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else { return nil }

        let monthlyAnnual = monthly.price * 12
        let savings = (monthlyAnnual - yearly.price) / monthlyAnnual * 100
        return Int(truncating: NSDecimalNumber(decimal: savings))
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension PurchaseManager {
    /// Creates a mock manager for previews
    static var preview: PurchaseManager {
        let manager = PurchaseManager.shared
        // In previews, we can't actually load products
        // The real manager will work in the app
        return manager
    }

    /// Simulates premium status for previews
    static var previewPremium: PurchaseManager {
        let manager = PurchaseManager.shared
        manager.setPreviewPremium(true)
        return manager
    }

    /// Helper for previews to set premium state
    func setPreviewPremium(_ value: Bool) {
        isPremium = value
        if value {
            subscriptionStatus = .subscribed(
                expirationDate: Date().addingTimeInterval(86400 * 30),
                productId: "com.kreativekoala.aitranslate.monthly"
            )
        } else {
            subscriptionStatus = .notSubscribed
        }
    }
}
#endif
