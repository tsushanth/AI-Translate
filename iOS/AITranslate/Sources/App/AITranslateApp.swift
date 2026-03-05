import SwiftUI

/// Main application entry point
@main
struct AITranslateApp: App {
    @State private var hasCompletedOnboarding = OnboardingManager.shared.hasCompletedOnboarding
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Start the 7-day trial for existing users who already completed onboarding
        // This ensures users who update the app also get the trial
        if OnboardingManager.shared.hasCompletedOnboarding {
            PurchaseManager.shared.startTrialIfNeeded()
        }

        // Trigger offline model restoration in the background
        Task {
            await OfflineModelManager.shared.restoreModelIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView {
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    }
                }

                // Hidden helper view for Apple Translation (iOS 18+)
                if #available(iOS 18.0, *) {
                    TranslationHelperView()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Restore model when app becomes active (in case it was unloaded due to memory pressure)
                    Task {
                        await OfflineModelManager.shared.restoreModelIfNeeded()
                    }
                }
            }
        }
    }
}
