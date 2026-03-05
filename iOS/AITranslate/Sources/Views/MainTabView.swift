import SwiftUI
import Network

/// Main tab-based navigation container
@MainActor
struct MainTabView: View {
    @StateObject private var historyStore = HistoryStore.shared
    @StateObject private var translateViewModel = TranslateViewModel()
    @StateObject private var networkMonitor = NetworkMonitor()
    @Bindable private var settings = SettingsStore.shared

    @State private var selectedTab: Tab = .text

    enum Tab: Hashable {
        case text
        case camera
        case voice
        case phrasebook
        case more
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Text Tab (Translation) - Requires internet
            TextTranslateView(viewModel: translateViewModel)
                .tabItem {
                    Label("Text", systemImage: "text.alignleft")
                }
                .tag(Tab.text)

            // Camera Tab (OCR Translation) - Requires internet
            CameraTranslateView()
                .tabItem {
                    Label("Camera", systemImage: "camera")
                }
                .tag(Tab.camera)

            // Voice Tab (Conversation Mode) - Works offline with downloaded languages!
            VoiceConversationView()
                .tabItem {
                    Label("Voice", systemImage: networkMonitor.isOnline ? "mic" : "mic.circle.fill")
                }
                .tag(Tab.voice)

            // Phrasebook Tab - Works offline (local storage)
            PhrasebookView(
                onOpenInTranslator: { phrase, targetLanguage in
                    loadPhraseInTranslator(phrase, targetLanguage: targetLanguage)
                }
            )
            .tabItem {
                Label("Phrasebook", systemImage: "book")
            }
            .tag(Tab.phrasebook)

            // More Tab (Settings)
            SettingsView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
                .tag(Tab.more)
        }
        .preferredColorScheme(settings.appColorScheme.colorScheme)
        .environmentObject(networkMonitor)
        .onReceive(NotificationCenter.default.publisher(for: .openVoiceTranslation)) { _ in
            selectedTab = .voice
        }
    }

    // MARK: - Navigation Actions

    /// Load a history entry in the translator
    private func loadEntryInTranslator(_ entry: TranslationEntry, andSpeak: Bool) {
        translateViewModel.loadEntry(entry)
        selectedTab = .text

        // Speak after a short delay to allow UI to settle
        if andSpeak {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                translateViewModel.speakTranslation()
            }
        }
    }

    /// Load a phrasebook phrase in the translator
    private func loadPhraseInTranslator(_ phrase: Phrase, targetLanguage: Language) {
        translateViewModel.sourceText = phrase.text
        translateViewModel.sourceLanguage = Language.find(byCode: "en") ?? .autoDetect
        translateViewModel.targetLanguage = targetLanguage
        translateViewModel.translate()
        selectedTab = .text
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Main Tab View") {
    MainTabView()
}
#endif
