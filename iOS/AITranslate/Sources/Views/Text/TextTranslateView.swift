import SwiftUI

/// Redesigned text translation view with dark card-based UI
@MainActor
struct TextTranslateView: View {
    @StateObject private var viewModel: TranslateViewModel
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @State private var showFullscreen = false
    @FocusState private var isTextEditorFocused: Bool

    init(viewModel: TranslateViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Background - tap to dismiss keyboard
            Color(.systemBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    isTextEditorFocused = false
                }

            VStack(spacing: 0) {
                // Top bar
                topBar

                ScrollView {
                    VStack(spacing: 16) {
                        // Source text card
                        sourceCard

                        // Translation card
                        if !viewModel.translatedText.isEmpty || viewModel.isTranslating {
                            translationCard
                        }

                        // Action bar
                        if !viewModel.translatedText.isEmpty {
                            actionBar
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)

                // Bottom language selector
                languageSelector
            }

            // Offline overlay
            if !networkMonitor.isOnline {
                OfflineUnavailableOverlay(
                    feature: "Text Translation",
                    suggestion: "Use Voice tab for offline translation"
                )
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            FullscreenTranslationView(
                sourceText: viewModel.sourceText,
                translatedText: viewModel.translatedText,
                sourceLanguage: viewModel.sourceLanguage,
                targetLanguage: viewModel.targetLanguage,
                onSpeak: { viewModel.speakTranslation() },
                isSpeaking: viewModel.isSpeaking
            )
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("SayIt AI")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            // Settings button - removed since settings is now in More tab
        }
        .padding()
    }

    // MARK: - Source Card

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Language header
            HStack {
                Text(viewModel.sourceLanguageDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Speaker button
                Button {
                    viewModel.speakSource()
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.body)
                        .foregroundStyle(viewModel.sourceText.isEmpty ? .tertiary : .secondary)
                }
                .disabled(viewModel.sourceText.isEmpty)
            }

            // Text input
            ZStack(alignment: .topLeading) {
                if viewModel.sourceText.isEmpty {
                    Text("Enter text to translate")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }

                TextEditor(text: $viewModel.sourceText)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($isTextEditorFocused)
            }

            // Clear text button (shows when there's text)
            if !viewModel.sourceText.isEmpty {
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Button {
                            viewModel.sourceText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 8)
                        .padding(.trailing, 4)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Translation Card

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Language header
            HStack {
                Text(viewModel.targetLanguage.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Speaker button
                Button {
                    viewModel.toggleSpeakTranslation()
                } label: {
                    Image(systemName: viewModel.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.body)
                        .foregroundStyle(viewModel.isSpeaking ? .blue : .secondary)
                }
                .disabled(viewModel.translatedText.isEmpty)
            }

            // Translation text
            if viewModel.isTranslating {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Translating...")
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 80)
            } else {
                Text(viewModel.translatedText)
                    .font(.body)
                    .frame(minHeight: 80, alignment: .topLeading)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            // Clear button
            Button {
                viewModel.clear()
            } label: {
                Text("Clear")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }

            Spacer()

            // Favorite
            Button {
                viewModel.toggleFavorite()
            } label: {
                Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(viewModel.isFavorite ? .red : .blue)
            }
            .padding(.horizontal, 16)

            // Copy
            Button {
                viewModel.copyTranslation()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 16)

            // Fullscreen
            Button {
                showFullscreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 16)

            // Share
            ShareLink(item: viewModel.translatedText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Language Selector

    private var languageSelector: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 12) {
                // Source language button
                LanguagePillButton(
                    language: viewModel.sourceLanguage,
                    languages: Language.sourceLanguages,
                    selection: $viewModel.sourceLanguage
                )

                // Swap button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.swapLanguages()
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.body)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                }
                .disabled(!viewModel.canSwapLanguages)

                // Target language button
                LanguagePillButton(
                    language: viewModel.targetLanguage,
                    languages: Language.targetLanguages,
                    selection: $viewModel.targetLanguage
                )
            }
            .padding(.horizontal)

            // Bottom action row with keyboard dismiss, speaker, clear, and translate
            HStack(spacing: 16) {
                // Keyboard dismiss button (only visible when keyboard is shown)
                Button {
                    isTextEditorFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3)
                        .foregroundColor(isTextEditorFocused ? .blue : .gray.opacity(0.5))
                }
                .disabled(!isTextEditorFocused)

                // Speaker button for source text
                Button {
                    viewModel.speakSource()
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.title3)
                        .foregroundColor(viewModel.sourceText.isEmpty ? .gray.opacity(0.5) : .blue)
                }
                .disabled(viewModel.sourceText.isEmpty)

                Spacer()

                // Clear button
                if !viewModel.sourceText.isEmpty || !viewModel.translatedText.isEmpty {
                    Button {
                        viewModel.clear()
                    } label: {
                        Text("Clear")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }

                // Translate button
                Button {
                    isTextEditorFocused = false
                    viewModel.translate()
                } label: {
                    Text("Translate")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(viewModel.canTranslate && !viewModel.isTranslating ? Color.blue : Color.gray)
                        )
                }
                .disabled(!viewModel.canTranslate || viewModel.isTranslating)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Language Pill Button

struct LanguagePillButton: View {
    let language: Language
    let languages: [Language]
    @Binding var selection: Language

    var body: some View {
        Menu {
            ForEach(languages, id: \.code) { lang in
                Button {
                    selection = lang
                } label: {
                    HStack {
                        Text(lang.flagEmoji)
                        Text(lang.displayName)
                        if lang.code == selection.code {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(language.flagEmoji)
                    .font(.title3)
                Text(language.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Fullscreen Translation View

struct FullscreenTranslationView: View {
    let sourceText: String
    let translatedText: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let onSpeak: () -> Void
    let isSpeaking: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding()

                Spacer()

                // Translation display
                VStack(spacing: 32) {
                    // Source text
                    VStack(spacing: 8) {
                        Text(sourceLanguage.displayName)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(sourceText)
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    // Translation
                    VStack(spacing: 8) {
                        Text(targetLanguage.displayName)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(translatedText)
                            .font(.largeTitle)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Speak button
                Button {
                    onSpeak()
                } label: {
                    Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Color.blue))
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    TextTranslateView(viewModel: TranslateViewModel())
}
#endif
