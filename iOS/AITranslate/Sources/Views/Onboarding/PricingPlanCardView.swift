import SwiftUI

/// Reusable pricing plan card component for subscription selection
struct PricingPlanCardView: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isLoading: Bool
    let onSelect: () -> Void

    init(
        plan: SubscriptionPlan,
        isSelected: Bool,
        isLoading: Bool = false,
        onSelect: @escaping () -> Void
    ) {
        self.plan = plan
        self.isSelected = isSelected
        self.isLoading = isLoading
        self.onSelect = onSelect
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Plan details
                VStack(alignment: .leading, spacing: 4) {
                    // Badge (if present)
                    if let badge = plan.badge {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.orange)
                            )
                    }

                    // Plan name
                    Text(plan.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    // Subtitle (trial info + monthly price)
                    if let subtitle = plan.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Price section
                if isLoading {
                    // Loading state
                    VStack(alignment: .trailing, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 60, height: 20)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 50, height: 14)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(plan.price)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text("per \(plan.period)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Skeleton Loading Card

struct PricingPlanSkeletonView: View {
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 80, height: 20)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 120, height: 14)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 60, height: 20)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 50, height: 14)
            }

            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 28, height: 28)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Plan Cards") {
    VStack(spacing: 12) {
        PricingPlanCardView(
            plan: SubscriptionPlan.placeholderPlans[0],
            isSelected: true,
            onSelect: {}
        )

        PricingPlanCardView(
            plan: SubscriptionPlan.placeholderPlans[1],
            isSelected: false,
            onSelect: {}
        )

        PricingPlanCardView(
            plan: SubscriptionPlan.placeholderPlans[0],
            isSelected: false,
            isLoading: true,
            onSelect: {}
        )

        PricingPlanSkeletonView()
    }
    .padding()
    .background(Color(.systemBackground))
}
#endif
