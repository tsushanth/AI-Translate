import SwiftUI

/// View showing all phrases in a category
struct PhraseListView: View {
    let category: PhraseCategory
    @ObservedObject var viewModel: PhrasebookViewModel

    /// Callback to open phrase in main translator
    var onOpenInTranslator: ((Phrase, Language) -> Void)?

    @State private var selectedPhrase: Phrase?
    @State private var showTranslation = false

    var body: some View {
        List {
            ForEach(category.phrases) { phrase in
                PhraseRow(
                    phrase: phrase,
                    onTap: {
                        selectedPhrase = phrase
                        viewModel.translate(phrase)
                        showTranslation = true
                    },
                    onSpeak: {
                        viewModel.speakOriginal(phrase)
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showTranslation) {
            if let phrase = selectedPhrase {
                PhraseTranslationSheet(
                    phrase: phrase,
                    viewModel: viewModel,
                    onOpenInTranslator: onOpenInTranslator
                )
                .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Phrase Row

struct PhraseRow: View {
    let phrase: Phrase
    let onTap: () -> Void
    let onSpeak: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phrase.text)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let context = phrase.context {
                        Text(context)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Speak button
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Translation Sheet

struct PhraseTranslationSheet: View {
    let phrase: Phrase
    @ObservedObject var viewModel: PhrasebookViewModel

    var onOpenInTranslator: ((Phrase, Language) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedFeedback = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Original phrase
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("English")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            viewModel.speakOriginal(phrase)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(phrase.text)
                        .font(.title3)
                        .fontWeight(.medium)

                    if let context = phrase.context {
                        Text(context)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Arrow
                Image(systemName: "arrow.down")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                // Translation
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewModel.targetLanguage.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if viewModel.currentTranslation != nil {
                            Button {
                                viewModel.speakTranslation()
                            } label: {
                                Image(systemName: "speaker.wave.2")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if viewModel.isTranslating {
                        HStack {
                            ProgressView()
                            Text("Translating...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                    } else if let translation = viewModel.currentTranslation {
                        Text(translation.translatedText)
                            .font(.title3)
                            .fontWeight(.medium)
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)

                Spacer()

                // Action buttons
                if viewModel.currentTranslation != nil {
                    actionButtons
                }
            }
            .padding()
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.clearTranslation()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showLanguagePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.targetLanguage.shortDisplayName)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showLanguagePicker) {
                LanguagePickerSheet(
                    title: "Translate To",
                    languages: Language.targetLanguages,
                    selection: $viewModel.targetLanguage
                )
            }
            .onChange(of: viewModel.targetLanguage) { _, _ in
                // Re-translate when language changes
                viewModel.translate(phrase)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Copy button
            Button {
                viewModel.copyTranslation()
                showCopiedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopiedFeedback = false
                }
            } label: {
                Label(
                    showCopiedFeedback ? "Copied!" : "Copy",
                    systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.tertiarySystemBackground))
                .foregroundStyle(showCopiedFeedback ? .green : .primary)
                .cornerRadius(10)
            }

            // Open in translator button
            if let onOpenInTranslator = onOpenInTranslator {
                Button {
                    onOpenInTranslator(phrase, viewModel.targetLanguage)
                    dismiss()
                } label: {
                    Label("Open in Translator", systemImage: "arrow.up.forward.square")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Phrase List") {
    NavigationStack {
        PhraseListView(
            category: PhrasebookData.basics,
            viewModel: .preview
        )
    }
}

#Preview("Translation Sheet") {
    PhraseTranslationSheet(
        phrase: Phrase(text: "Hello", context: "Greeting"),
        viewModel: .previewWithTranslation
    )
}

#Preview("Translation Sheet - Loading") {
    PhraseTranslationSheet(
        phrase: Phrase(text: "Hello", context: "Greeting"),
        viewModel: .previewLoading
    )
}
#endif
