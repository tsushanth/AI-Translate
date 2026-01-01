import Foundation

/// Represents a single onboarding page
struct OnboardingPage: Identifiable, Equatable {
    let id: Int
    let title: String
    let subtitle: String
    let systemImage: String
    let imageColor: OnboardingImageColor

    /// Predefined onboarding pages
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            title: "Speak Any Language Instantly",
            subtitle: "Break language barriers with real-time text, voice, and camera translation in 30+ languages.",
            systemImage: "globe",
            imageColor: .blue
        ),
        OnboardingPage(
            id: 1,
            title: "Have Real Conversations",
            subtitle: "Speak naturally and hear translations aloud. Perfect for travel, business, or making new friends.",
            systemImage: "waveform.circle.fill",
            imageColor: .purple
        ),
        OnboardingPage(
            id: 2,
            title: "Translate the World Around You",
            subtitle: "Point your camera at signs, menus, or documents. Save your favorites to your personal phrasebook.",
            systemImage: "camera.viewfinder",
            imageColor: .orange
        )
    ]
}

/// Color scheme for onboarding images
enum OnboardingImageColor: Equatable {
    case blue
    case purple
    case orange
    case green

    var primaryColor: String {
        switch self {
        case .blue: return "systemBlue"
        case .purple: return "systemPurple"
        case .orange: return "systemOrange"
        case .green: return "systemGreen"
        }
    }
}
