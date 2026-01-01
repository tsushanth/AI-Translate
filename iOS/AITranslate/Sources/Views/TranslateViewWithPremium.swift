import SwiftUI

/// Example: TranslateView with premium feature gating
/// This shows how to integrate premium checks into the translation flow
@MainActor
struct TranslateViewWithPremium: View {
    @StateObject private var viewModel = TranslateViewModel()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var usageTracker = UsageTracker.shared

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Translation limit banner (only for free users)
                    TranslationLimitBanner()
                        .padding(.horizontal)

                    // Language selector bar
                    languageSelectorBar
                        .padding(.horizontal)

                    // Source text input
                    sourceTextSection
                        .padding(.horizontal)

                    // Action buttons row
                    actionButtonsRow

                    // Translated text output
                    translatedTextSection
                        .padding(.horizontal)

                    // Translate button
                    translateButton
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Premium status indicator
                ToolbarItem(placement: .topBarLeading) {
                    if purchaseManager.isPremium {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                            Text("PRO")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.hasContent {
                        Button("Clear") {
                            viewModel.clear()
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Language Selector Bar

    private var languageSelectorBar: some View {
        HStack(spacing: 8) {
            LanguagePickerButton(
                title: "From",
                language: viewModel.sourceLanguage,
                languages: Language.sourceLanguages,
                selection: $viewModel.sourceLanguage
            )

            SwapLanguagesButton(
                isDisabled: !viewModel.canSwapLanguages
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.swapLanguages()
                }
            }

            LanguagePickerButton(
                title: "To",
                language: viewModel.targetLanguage,
                languages: Language.targetLanguages,
                selection: $viewModel.targetLanguage
            )
        }
    }

    // MARK: - Source Text Section

    private var sourceTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.sourceLanguageDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 12) {
                    // Speak source (premium feature)
                    speakSourceButton

                    CopyButton(isDisabled: viewModel.sourceText.isEmpty) {
                        viewModel.copySource()
                    }
                }
            }

            SourceTextEditor(
                text: $viewModel.sourceText,
                placeholder: "Enter text or tap mic to speak",
                isRecording: viewModel.isRecording
            ) {
                viewModel.clear()
            }
        }
    }

    // MARK: - Speak Source Button (Premium Gated)

    private var speakSourceButton: some View {
        Button {
            if purchaseManager.isPremium {
                viewModel.speakSource()
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "speaker.wave.2")
                    .font(.subheadline)

                if !purchaseManager.isPremium {
                    PremiumBadge()
                }
            }
            .foregroundStyle(viewModel.sourceText.isEmpty ? .tertiary : .secondary)
        }
        .disabled(viewModel.sourceText.isEmpty)
    }

    // MARK: - Action Buttons Row

    private var actionButtonsRow: some View {
        HStack(spacing: 24) {
            Spacer()

            // Microphone button (premium gated)
            microphoneButton

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Microphone Button (Premium Gated)

    private var microphoneButton: some View {
        ZStack(alignment: .topTrailing) {
            MicrophoneButton(isRecording: viewModel.isRecording) {
                if purchaseManager.isPremium {
                    Task {
                        await viewModel.toggleVoiceInput()
                    }
                } else {
                    showPaywall = true
                }
            }

            // Premium badge overlay
            if !purchaseManager.isPremium {
                PremiumBadge()
                    .offset(x: 8, y: -8)
            }
        }
    }

    // MARK: - Translated Text Section

    private var translatedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.targetLanguage.shortDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 12) {
                    FavoriteButton(
                        isFavorite: viewModel.isFavorite,
                        isDisabled: viewModel.translatedText.isEmpty
                    ) {
                        // Check favorites limit for free users
                        checkFavoritesLimitAndToggle()
                    }

                    // Speaker button (premium gated)
                    speakerButton

                    CopyButton(isDisabled: viewModel.translatedText.isEmpty) {
                        viewModel.copyTranslation()
                    }
                }
            }

            TranslatedTextView(
                text: viewModel.translatedText,
                isLoading: viewModel.isTranslating
            )
        }
    }

    // MARK: - Speaker Button (Premium Gated)

    private var speakerButton: some View {
        Button {
            if purchaseManager.isPremium {
                viewModel.toggleSpeakTranslation()
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(viewModel.isSpeaking ? Color.accentColor : .secondary)

                if !purchaseManager.isPremium {
                    PremiumBadge()
                }
            }
            .frame(width: 44, height: 32)
        }
        .disabled(viewModel.translatedText.isEmpty)
        .buttonStyle(.plain)
    }

    // MARK: - Translate Button

    private var translateButton: some View {
        Button {
            // Check translation limit
            if !usageTracker.canTranslate && !purchaseManager.isPremium {
                showPaywall = true
                return
            }

            viewModel.translate()

            // Record usage for free users
            if !purchaseManager.isPremium {
                usageTracker.recordTranslation()
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isTranslating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                }
                Text(translateButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.canTranslate ? Color.accentColor : Color.gray)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canTranslate || viewModel.isTranslating)
    }

    private var translateButtonTitle: String {
        if viewModel.isTranslating {
            return "Translating..."
        }

        if !purchaseManager.isPremium && !usageTracker.canTranslate {
            return "Upgrade to Continue"
        }

        return "Translate"
    }

    // MARK: - Favorites Limit Check

    private func checkFavoritesLimitAndToggle() {
        // If already a favorite, always allow unfavoriting
        if viewModel.isFavorite {
            viewModel.toggleFavorite()
            return
        }

        // Check if free user has reached favorites limit
        if !purchaseManager.isPremium {
            let currentFavorites = HistoryStore.shared.favoritesCount
            if currentFavorites >= FreeTierLimits.maxFavorites {
                showPaywall = true
                return
            }
        }

        viewModel.toggleFavorite()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Free User") {
    TranslateViewWithPremium()
}

#Preview("Premium User") {
    // Premium preview uses previewPremium static helper
    let _ = PurchaseManager.previewPremium
    return TranslateViewWithPremium()
}
#endif
