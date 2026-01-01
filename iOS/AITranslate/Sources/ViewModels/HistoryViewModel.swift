import Foundation
import SwiftUI
import Combine

/// Display mode for history view
enum HistoryDisplayMode: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "clock"
        case .favorites: return "star.fill"
        }
    }
}

/// ViewModel for the History/Favorites screen
@MainActor
final class HistoryViewModel: ObservableObject {

    // MARK: - Published State

    /// Current display mode (all history or favorites only)
    @Published var displayMode: HistoryDisplayMode = .all

    /// Search query
    @Published var searchQuery: String = ""

    /// Whether edit mode is active
    @Published var isEditing: Bool = false

    /// Selected entries for batch operations
    @Published var selectedEntries: Set<UUID> = []

    /// Entry to speak (triggers TTS)
    @Published var speakingEntryId: UUID?

    /// Show clear confirmation dialog
    @Published var showClearConfirmation: Bool = false

    /// Show delete confirmation dialog
    @Published var showDeleteConfirmation: Bool = false

    // MARK: - Dependencies

    private let historyStore: HistoryStore
    private let textToSpeechService: TextToSpeechService

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        historyStore: HistoryStore = .shared,
        textToSpeechService: TextToSpeechService = TextToSpeechService()
    ) {
        self.historyStore = historyStore
        self.textToSpeechService = textToSpeechService

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Clear selection when exiting edit mode
        $isEditing
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.selectedEntries.removeAll()
            }
            .store(in: &cancellables)

        // Stop speaking when entry changes
        $speakingEntryId
            .dropFirst()
            .sink { [weak self] entryId in
                if entryId == nil {
                    self?.textToSpeechService.stop()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    /// Filtered entries based on display mode and search
    var filteredEntries: [TranslationEntry] {
        let baseEntries: [TranslationEntry]

        switch displayMode {
        case .all:
            baseEntries = historyStore.entries
        case .favorites:
            baseEntries = historyStore.favorites
        }

        guard !searchQuery.isEmpty else {
            return baseEntries
        }

        let query = searchQuery.lowercased()
        return baseEntries.filter {
            $0.sourceText.lowercased().contains(query) ||
            $0.translatedText.lowercased().contains(query)
        }
    }

    /// Whether the list is empty
    var isEmpty: Bool {
        filteredEntries.isEmpty
    }

    /// Empty state message
    var emptyMessage: String {
        if !searchQuery.isEmpty {
            return "No results found"
        }

        switch displayMode {
        case .all:
            return "No translations yet"
        case .favorites:
            return "No favorites yet"
        }
    }

    /// Empty state icon
    var emptyIcon: String {
        if !searchQuery.isEmpty {
            return "magnifyingglass"
        }

        switch displayMode {
        case .all:
            return "clock"
        case .favorites:
            return "star"
        }
    }

    /// Count badge for favorites tab
    var favoritesCount: Int {
        historyStore.favoritesCount
    }

    /// Count badge for all tab
    var allCount: Int {
        historyStore.entries.count
    }

    /// Whether any entries are selected
    var hasSelection: Bool {
        !selectedEntries.isEmpty
    }

    /// Number of selected entries
    var selectionCount: Int {
        selectedEntries.count
    }

    // MARK: - Actions

    /// Toggle selection for an entry
    func toggleSelection(_ entry: TranslationEntry) {
        if selectedEntries.contains(entry.id) {
            selectedEntries.remove(entry.id)
        } else {
            selectedEntries.insert(entry.id)
        }
    }

    /// Select all visible entries
    func selectAll() {
        selectedEntries = Set(filteredEntries.map(\.id))
    }

    /// Deselect all entries
    func deselectAll() {
        selectedEntries.removeAll()
    }

    /// Delete a single entry
    func delete(_ entry: TranslationEntry) {
        historyStore.remove(id: entry.id)
    }

    /// Delete selected entries
    func deleteSelected() {
        historyStore.removeMultiple(ids: selectedEntries)
        selectedEntries.removeAll()
        isEditing = false
    }

    /// Toggle favorite status for an entry
    func toggleFavorite(_ entry: TranslationEntry) {
        historyStore.toggleFavorite(id: entry.id)
    }

    /// Clear all history (optionally keep favorites)
    func clearHistory(keepFavorites: Bool = true) {
        historyStore.clearHistory(keepFavorites: keepFavorites)
    }

    /// Speak the translated text of an entry
    func speak(_ entry: TranslationEntry) {
        if speakingEntryId == entry.id {
            // Stop if already speaking this entry
            textToSpeechService.stop()
            speakingEntryId = nil
        } else {
            // Speak new entry
            let languageCode = Language.find(byCode: entry.targetLanguage)?.speechLocaleCode
                ?? entry.targetLanguage

            textToSpeechService.delegate = self
            textToSpeechService.speak(text: entry.translatedText, languageCode: languageCode)
            speakingEntryId = entry.id
        }
    }

    /// Stop any current speech
    func stopSpeaking() {
        textToSpeechService.stop()
        speakingEntryId = nil
    }

    /// Check if an entry is currently being spoken
    func isSpeaking(_ entry: TranslationEntry) -> Bool {
        speakingEntryId == entry.id
    }

    // MARK: - Entry Grouping

    /// Entries grouped by relative date
    var groupedEntries: [(title: String, entries: [TranslationEntry])] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!

        var groups: [(title: String, entries: [TranslationEntry])] = []
        var todayEntries: [TranslationEntry] = []
        var yesterdayEntries: [TranslationEntry] = []
        var thisWeekEntries: [TranslationEntry] = []
        var olderEntries: [TranslationEntry] = []

        for entry in filteredEntries {
            let entryDate = calendar.startOfDay(for: entry.createdAt)

            if entryDate == today {
                todayEntries.append(entry)
            } else if entryDate == yesterday {
                yesterdayEntries.append(entry)
            } else if entryDate > lastWeek {
                thisWeekEntries.append(entry)
            } else {
                olderEntries.append(entry)
            }
        }

        if !todayEntries.isEmpty {
            groups.append((title: "Today", entries: todayEntries))
        }
        if !yesterdayEntries.isEmpty {
            groups.append((title: "Yesterday", entries: yesterdayEntries))
        }
        if !thisWeekEntries.isEmpty {
            groups.append((title: "This Week", entries: thisWeekEntries))
        }
        if !olderEntries.isEmpty {
            groups.append((title: "Older", entries: olderEntries))
        }

        return groups
    }
}

// MARK: - TextToSpeechDelegate

extension HistoryViewModel: TextToSpeechDelegate {

    nonisolated func textToSpeechDidStart() {
        // Already set speakingEntryId before starting
    }

    nonisolated func textToSpeechDidFinish() {
        Task { @MainActor in
            speakingEntryId = nil
        }
    }

    nonisolated func textToSpeechDidCancel() {
        Task { @MainActor in
            speakingEntryId = nil
        }
    }

    nonisolated func textToSpeech(didFailWithError error: TextToSpeechError) {
        Task { @MainActor in
            speakingEntryId = nil
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension HistoryViewModel {
    static var preview: HistoryViewModel {
        HistoryViewModel(historyStore: .preview)
    }

    static var previewEmpty: HistoryViewModel {
        HistoryViewModel(historyStore: .previewEmpty)
    }

    static var previewFavorites: HistoryViewModel {
        let vm = HistoryViewModel(historyStore: .preview)
        vm.displayMode = .favorites
        return vm
    }
}
#endif
