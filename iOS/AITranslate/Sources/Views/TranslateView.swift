import SwiftUI

/// Main translation screen
@MainActor
struct TranslateView: View {
    @StateObject private var viewModel: TranslateViewModel

    init(viewModel: TranslateViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Language selector bar
                    languageSelectorBar

                    // Source text input
                    sourceTextSection

                    // Action buttons row
                    actionButtonsRow

                    // Translated text output
                    translatedTextSection

                    // Translate button
                    TranslateButton(
                        isLoading: viewModel.isTranslating,
                        isDisabled: !viewModel.canTranslate
                    ) {
                        viewModel.translate()
                    }
                }
                .padding()
            }
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.hasContent {
                        Button("Clear") {
                            viewModel.clear()
                        }
                    }
                }
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
            // Source language picker
            LanguagePickerButton(
                title: "From",
                language: viewModel.sourceLanguage,
                languages: Language.sourceLanguages,
                selection: $viewModel.sourceLanguage
            )

            // Swap button
            SwapLanguagesButton(
                isDisabled: !viewModel.canSwapLanguages
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.swapLanguages()
                }
            }

            // Target language picker
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
            // Header with detected language
            HStack {
                Text(viewModel.sourceLanguageDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Source text actions
                HStack(spacing: 12) {
                    // Speak source
                    Button {
                        viewModel.speakSource()
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.subheadline)
                            .foregroundStyle(viewModel.sourceText.isEmpty ? .tertiary : .secondary)
                    }
                    .disabled(viewModel.sourceText.isEmpty)

                    // Copy source
                    CopyButton(isDisabled: viewModel.sourceText.isEmpty) {
                        viewModel.copySource()
                    }
                }
            }

            // Text editor
            SourceTextEditor(
                text: $viewModel.sourceText,
                placeholder: "Enter text or tap mic to speak",
                isRecording: viewModel.isRecording
            ) {
                viewModel.clear()
            }
        }
    }

    // MARK: - Action Buttons Row

    private var actionButtonsRow: some View {
        HStack(spacing: 24) {
            Spacer()

            // Microphone button
            MicrophoneButton(isRecording: viewModel.isRecording) {
                Task {
                    await viewModel.toggleVoiceInput()
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Translated Text Section

    private var translatedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(viewModel.targetLanguage.shortDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Translation actions
                HStack(spacing: 12) {
                    // Favorite
                    FavoriteButton(
                        isFavorite: viewModel.isFavorite,
                        isDisabled: viewModel.translatedText.isEmpty
                    ) {
                        viewModel.toggleFavorite()
                    }

                    // Speak translation
                    SpeakerButton(
                        isSpeaking: viewModel.isSpeaking,
                        isDisabled: viewModel.translatedText.isEmpty
                    ) {
                        viewModel.toggleSpeakTranslation()
                    }

                    // Copy translation
                    CopyButton(isDisabled: viewModel.translatedText.isEmpty) {
                        viewModel.copyTranslation()
                    }
                }
            }

            // Translated text display
            TranslatedTextView(
                text: viewModel.translatedText,
                isLoading: viewModel.isTranslating
            )
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty State") {
    TranslateView(viewModel: .previewEmpty)
}

#Preview("With Translation") {
    TranslateView(viewModel: .preview)
}

#Preview("Loading") {
    TranslateView(viewModel: .previewLoading)
}

#Preview("Recording") {
    TranslateView(viewModel: .previewRecording)
}
#endif
