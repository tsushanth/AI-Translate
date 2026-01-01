import Foundation
import StoreKit

/// Represents a subscription plan option
struct SubscriptionPlan: Identifiable, Equatable {
    let id: String
    let name: String
    let price: String
    let pricePerMonth: String?
    let period: String
    let trialInfo: String?
    let badge: String?
    let isBestValue: Bool
    let storeProduct: Product?

    static func == (lhs: SubscriptionPlan, rhs: SubscriptionPlan) -> Bool {
        lhs.id == rhs.id
    }

    /// Creates a SubscriptionPlan from a StoreKit Product
    init(from product: Product, isBestValue: Bool = false, savingsPercent: Int? = nil) {
        self.id = product.id
        self.name = product.displayName
        self.price = product.displayPrice
        self.storeProduct = product

        // Calculate period text
        if let subscription = product.subscription {
            self.period = subscription.subscriptionPeriod.periodText

            // Calculate price per month for yearly plans
            if subscription.subscriptionPeriod.unit == .year {
                let monthlyPrice = product.price / 12
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.locale = product.priceFormatStyle.locale
                self.pricePerMonth = formatter.string(from: NSDecimalNumber(decimal: monthlyPrice))
            } else {
                self.pricePerMonth = nil
            }

            // Get trial info
            if let introOffer = subscription.introductoryOffer {
                self.trialInfo = introOffer.displayText
            } else {
                self.trialInfo = nil
            }
        } else {
            self.period = ""
            self.pricePerMonth = nil
            self.trialInfo = nil
        }

        // Set badge for best value
        if isBestValue, let savings = savingsPercent, savings > 0 {
            self.badge = "SAVE \(savings)%"
        } else if isBestValue {
            self.badge = "BEST VALUE"
        } else {
            self.badge = nil
        }

        self.isBestValue = isBestValue
    }

    /// Creates a placeholder SubscriptionPlan
    init(
        id: String,
        name: String,
        price: String,
        pricePerMonth: String? = nil,
        period: String,
        trialInfo: String? = nil,
        badge: String? = nil,
        isBestValue: Bool = false
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.pricePerMonth = pricePerMonth
        self.period = period
        self.trialInfo = trialInfo
        self.badge = badge
        self.isBestValue = isBestValue
        self.storeProduct = nil
    }

    /// Subtitle combining trial info and price per month
    var subtitle: String? {
        var parts: [String] = []

        if let trial = trialInfo {
            parts.append(trial)
        }

        if let monthly = pricePerMonth {
            parts.append("\(monthly)/mo")
        }

        if parts.isEmpty {
            return period == "month" ? "Cancel anytime" : nil
        }

        return parts.joined(separator: " · ")
    }

    /// Placeholder subscription plans (shown while loading)
    static let placeholderPlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: "yearly_placeholder",
            name: "Annual",
            price: "$29.99",
            pricePerMonth: "$2.50",
            period: "year",
            trialInfo: "7-day free trial",
            badge: "BEST VALUE",
            isBestValue: true
        ),
        SubscriptionPlan(
            id: "monthly_placeholder",
            name: "Monthly",
            price: "$5.99",
            period: "month",
            trialInfo: nil,
            badge: nil,
            isBestValue: false
        )
    ]

    /// Returns the default placeholder plan
    static var defaultPlan: SubscriptionPlan {
        placeholderPlans.first { $0.isBestValue } ?? placeholderPlans[0]
    }
}

// MARK: - StoreKit Extensions

extension Product.SubscriptionPeriod {
    /// Human-readable period text
    var periodText: String {
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

    /// Short period text for display
    var shortPeriodText: String {
        switch unit {
        case .day: return "day"
        case .week: return "wk"
        case .month: return "mo"
        case .year: return "yr"
        @unknown default: return ""
        }
    }
}

extension Product.SubscriptionOffer {
    /// Display text for the offer (e.g., "7-day free trial")
    var displayText: String? {
        switch paymentMode {
        case .freeTrial:
            return "\(period.value)-\(period.unit.singularText) free trial"
        case .payUpFront:
            return "Pay upfront"
        case .payAsYouGo:
            return "Introductory price"
        default:
            return nil
        }
    }
}

extension Product.SubscriptionPeriod.Unit {
    /// Singular form of the unit
    var singularText: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return ""
        }
    }
}
