import SwiftUI

/// Main application entry point
@main
struct AITranslateApp: App {
    @State private var hasCompletedOnboarding = OnboardingManager.shared.hasCompletedOnboarding

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
    }
}
