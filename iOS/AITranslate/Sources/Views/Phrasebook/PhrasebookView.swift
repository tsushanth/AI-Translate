import SwiftUI

/// Main phrasebook view showing categories
@MainActor
struct PhrasebookView: View {
    @StateObject private var viewModel: PhrasebookViewModel

    /// Callback to open phrase in main translator
    var onOpenInTranslator: ((Phrase, Language) -> Void)?

    init(
        onOpenInTranslator: ((Phrase, Language) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: PhrasebookViewModel())
        self.onOpenInTranslator = onOpenInTranslator
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Target language selector
                languageSelector

                // Content
                if viewModel.isSearching {
                    searchResultsList
                } else {
                    categoryGrid
                }
            }
            .navigationTitle("Phrasebook")
            .searchable(text: $viewModel.searchQuery, prompt: "Search phrases")
            .sheet(isPresented: $viewModel.showLanguagePicker) {
                LanguagePickerSheet(
                    title: "Translate To",
                    languages: Language.targetLanguages,
                    selection: $viewModel.targetLanguage
                )
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

    // MARK: - Language Selector

    private var languageSelector: some View {
        Button {
            viewModel.showLanguagePicker = true
        } label: {
            HStack {
                Text("Translate to:")
                    .foregroundStyle(.secondary)

                Text(viewModel.targetLanguage.displayName)
                    .fontWeight(.medium)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(viewModel.categories) { category in
                    NavigationLink {
                        PhraseListView(
                            category: category,
                            viewModel: viewModel,
                            onOpenInTranslator: onOpenInTranslator
                        )
                    } label: {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        List {
            if viewModel.searchResults.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No phrases match \"\(viewModel.searchQuery)\"")
                )
            } else {
                ForEach(viewModel.searchResults, id: \.phrase.id) { result in
                    SearchResultRow(
                        category: result.category,
                        phrase: result.phrase,
                        viewModel: viewModel,
                        onOpenInTranslator: onOpenInTranslator
                    )
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: PhraseCategory

    private var categoryColor: Color {
        switch category.color {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "indigo": return .indigo
        default: return .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon
            Image(systemName: category.icon)
                .font(.title)
                .foregroundStyle(categoryColor)
                .frame(width: 44, height: 44)
                .background(categoryColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(category.phraseCount) phrases")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let category: PhraseCategory
    let phrase: Phrase
    @ObservedObject var viewModel: PhrasebookViewModel
    var onOpenInTranslator: ((Phrase, Language) -> Void)?

    @State private var showTranslation = false

    var body: some View {
        Button {
            showTranslation = true
            viewModel.translate(phrase)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(phrase.text)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(4)
                }

                if let context = phrase.context {
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showTranslation) {
            PhraseTranslationSheet(
                phrase: phrase,
                viewModel: viewModel,
                onOpenInTranslator: onOpenInTranslator
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Phrasebook") {
    PhrasebookView()
}
#endif
