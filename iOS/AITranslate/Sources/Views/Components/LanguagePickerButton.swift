import SwiftUI

/// Button that opens a language picker sheet
struct LanguagePickerButton: View {
    let title: String
    let language: Language
    let languages: [Language]
    @Binding var selection: Language

    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text(language.shortDisplayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            LanguagePickerSheet(
                title: title,
                languages: languages,
                selection: $selection
            )
        }
    }
}

/// Sheet view for selecting a language
struct LanguagePickerSheet: View {
    let title: String
    let languages: [Language]
    @Binding var selection: Language

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return languages
        }
        let query = searchText.lowercased()
        return languages.filter {
            $0.name.lowercased().contains(query) ||
            $0.nativeName.lowercased().contains(query) ||
            $0.code.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredLanguages) { language in
                Button {
                    selection = language
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.name)
                                .foregroundStyle(.primary)

                            if language.name != language.nativeName {
                                Text(language.nativeName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if language.id == selection.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search languages")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Language Picker Button") {
    struct PreviewWrapper: View {
        @State private var language = Language.find(byCode: "en")!

        var body: some View {
            VStack {
                LanguagePickerButton(
                    title: "From",
                    language: language,
                    languages: Language.sourceLanguages,
                    selection: $language
                )
                .padding()
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Language Picker Sheet") {
    struct PreviewWrapper: View {
        @State private var language = Language.find(byCode: "es")!

        var body: some View {
            LanguagePickerSheet(
                title: "Target Language",
                languages: Language.targetLanguages,
                selection: $language
            )
        }
    }

    return PreviewWrapper()
}
#endif
