import SwiftUI

/// Reusable onboarding card component for value proposition screens
struct OnboardingCardView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Illustration
            illustrationView

            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Illustration View

    private var illustrationView: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(iconGradient)
                .frame(width: 140, height: 140)

            // Outer glow effect
            Circle()
                .fill(iconGradient.opacity(0.3))
                .frame(width: 180, height: 180)
                .blur(radius: 20)

            // Icon
            Image(systemName: page.systemImage)
                .font(.system(size: 64))
                .fontWeight(.light)
                .foregroundStyle(.white)
        }
    }

    private var iconGradient: LinearGradient {
        switch page.imageColor {
        case .blue:
            return LinearGradient(
                colors: [Color.blue, Color.cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .purple:
            return LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .orange:
            return LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .green:
            return LinearGradient(
                colors: [Color.green, Color.mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Onboarding Card - Page 1") {
    OnboardingCardView(page: OnboardingPage.pages[0])
        .background(Color(.systemBackground))
}

#Preview("Onboarding Card - Page 2") {
    OnboardingCardView(page: OnboardingPage.pages[1])
        .background(Color(.systemBackground))
}

#Preview("Onboarding Card - Page 3") {
    OnboardingCardView(page: OnboardingPage.pages[2])
        .background(Color(.systemBackground))
}
#endif
