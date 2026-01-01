import SwiftUI

/// History and Favorites view
@MainActor
struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    @ObservedObject private var historyStore: HistoryStore

    /// Callback when user selects an entry to open in TranslateView
    var onSelectEntry: ((TranslationEntry) -> Void)?

    /// Optional callback to also speak the translation
    var onSelectAndSpeak: ((TranslationEntry) -> Void)?

    init(
        historyStore: HistoryStore = .shared,
        onSelectEntry: ((TranslationEntry) -> Void)? = nil,
        onSelectAndSpeak: ((TranslationEntry) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(historyStore: historyStore))
        _historyStore = ObservedObject(wrappedValue: historyStore)
        self.onSelectEntry = onSelectEntry
        self.onSelectAndSpeak = onSelectAndSpeak
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker (All / Favorites)
                modePicker

                // Content
                if viewModel.isEmpty {
                    emptyStateView
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchQuery, prompt: "Search translations")
            .toolbar {
                toolbarContent
            }
            .confirmationDialog(
                "Clear History",
                isPresented: $viewModel.showClearConfirmation,
                titleVisibility: .visible
            ) {
                clearConfirmationButtons
            }
            .confirmationDialog(
                "Delete \(viewModel.selectionCount) items?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                deleteConfirmationButtons
            }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("Display Mode", selection: $viewModel.displayMode) {
            ForEach(HistoryDisplayMode.allCases) { mode in
                HStack {
                    Image(systemName: mode.icon)
                    Text(mode.rawValue)
                    if mode == .favorites && viewModel.favoritesCount > 0 {
                        Text("(\(viewModel.favoritesCount))")
                    }
                }
                .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(viewModel.emptyMessage, systemImage: viewModel.emptyIcon)
        } description: {
            if viewModel.searchQuery.isEmpty {
                switch viewModel.displayMode {
                case .all:
                    Text("Your translation history will appear here")
                case .favorites:
                    Text("Tap the star on a translation to save it as a favorite")
                }
            } else {
                Text("Try a different search term")
            }
        }
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            // Edit mode selection bar
            if viewModel.isEditing && !viewModel.filteredEntries.isEmpty {
                editModeSelectionBar
            }

            // Grouped entries
            ForEach(viewModel.groupedEntries, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.entries) { entry in
                        historyRow(for: entry)
                    }
                    .onDelete { indexSet in
                        deleteEntries(from: group.entries, at: indexSet)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: viewModel.filteredEntries.count)
    }

    private func historyRow(for entry: TranslationEntry) -> some View {
        HistoryRowView(
            entry: entry,
            isSelected: viewModel.selectedEntries.contains(entry.id),
            isSpeaking: viewModel.isSpeaking(entry),
            isEditing: viewModel.isEditing,
            onTap: {
                if viewModel.isEditing {
                    viewModel.toggleSelection(entry)
                } else {
                    onSelectEntry?(entry)
                }
            },
            onFavorite: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleFavorite(entry)
                }
            },
            onSpeak: {
                viewModel.speak(entry)
            },
            onDelete: {
                withAnimation {
                    viewModel.delete(entry)
                }
            }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    viewModel.delete(entry)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation {
                    viewModel.toggleFavorite(entry)
                }
            } label: {
                Label(
                    entry.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: entry.isFavorite ? "star.slash" : "star.fill"
                )
            }
            .tint(.yellow)
        }
        .contextMenu {
            contextMenuItems(for: entry)
        }
    }

    // MARK: - Edit Mode Selection Bar

    private var editModeSelectionBar: some View {
        HStack {
            Button(viewModel.selectedEntries.count == viewModel.filteredEntries.count ? "Deselect All" : "Select All") {
                if viewModel.selectedEntries.count == viewModel.filteredEntries.count {
                    viewModel.deselectAll()
                } else {
                    viewModel.selectAll()
                }
            }

            Spacer()

            if viewModel.hasSelection {
                Text("\(viewModel.selectionCount) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for entry: TranslationEntry) -> some View {
        Button {
            onSelectEntry?(entry)
        } label: {
            Label("Open in Translator", systemImage: "arrow.up.forward.square")
        }

        Button {
            onSelectAndSpeak?(entry)
        } label: {
            Label("Open & Speak", systemImage: "speaker.wave.2")
        }

        Divider()

        Button {
            viewModel.speak(entry)
        } label: {
            Label(
                viewModel.isSpeaking(entry) ? "Stop Speaking" : "Speak Translation",
                systemImage: viewModel.isSpeaking(entry) ? "speaker.slash" : "speaker.wave.2"
            )
        }

        Button {
            UIPasteboard.general.string = entry.translatedText
        } label: {
            Label("Copy Translation", systemImage: "doc.on.doc")
        }

        Button {
            UIPasteboard.general.string = entry.sourceText
        } label: {
            Label("Copy Original", systemImage: "doc.on.doc")
        }

        Divider()

        Button {
            viewModel.toggleFavorite(entry)
        } label: {
            Label(
                entry.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: entry.isFavorite ? "star.slash" : "star"
            )
        }

        Divider()

        Button(role: .destructive) {
            viewModel.delete(entry)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isEditing {
                Button("Done") {
                    viewModel.isEditing = false
                }
            } else if !viewModel.isEmpty {
                Menu {
                    Button {
                        viewModel.isEditing = true
                    } label: {
                        Label("Select", systemImage: "checkmark.circle")
                    }

                    Divider()

                    Button(role: .destructive) {
                        viewModel.showClearConfirmation = true
                    } label: {
                        Label("Clear History", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }

        // Delete button in edit mode
        if viewModel.isEditing && viewModel.hasSelection {
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Confirmation Dialogs

    @ViewBuilder
    private var clearConfirmationButtons: some View {
        Button("Clear All", role: .destructive) {
            viewModel.clearHistory(keepFavorites: false)
        }

        if viewModel.favoritesCount > 0 {
            Button("Clear History, Keep Favorites", role: .destructive) {
                viewModel.clearHistory(keepFavorites: true)
            }
        }

        Button("Cancel", role: .cancel) {}
    }

    @ViewBuilder
    private var deleteConfirmationButtons: some View {
        Button("Delete \(viewModel.selectionCount) Items", role: .destructive) {
            viewModel.deleteSelected()
        }

        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Helpers

    private func deleteEntries(from entries: [TranslationEntry], at indexSet: IndexSet) {
        for index in indexSet {
            viewModel.delete(entries[index])
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("With Entries") {
    HistoryView(historyStore: .preview)
}

#Preview("Empty State") {
    HistoryView(historyStore: .previewEmpty)
}

#Preview("Favorites") {
    HistoryView(historyStore: .preview)
}
#endif
