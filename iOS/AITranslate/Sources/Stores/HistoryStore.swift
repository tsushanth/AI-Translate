import Foundation
import Combine

/// Protocol for history persistence
protocol HistoryStoreProtocol: AnyObject {
    /// All translation entries (most recent first)
    var entries: [TranslationEntry] { get }

    /// Publisher for observing changes
    var entriesPublisher: AnyPublisher<[TranslationEntry], Never> { get }

    /// Adds a new translation to history
    func add(_ entry: TranslationEntry)

    /// Removes an entry by ID
    func remove(id: UUID)

    /// Clears all history
    func clearAll()

    /// Toggles favorite status for an entry
    func toggleFavorite(id: UUID)

    /// Updates an existing entry
    func update(_ entry: TranslationEntry)

    /// Finds an entry by ID
    func find(id: UUID) -> TranslationEntry?
}

/// Manages translation history with local persistence using UserDefaults + JSON
///
/// Design decisions:
/// - UserDefaults + JSON chosen over CoreData/SwiftData for simplicity
/// - Max 100 entries to keep storage reasonable (~500KB worst case)
/// - Deduplication by source text + language pair
/// - Favorites are stored inline (not separate store)
@MainActor
final class HistoryStore: ObservableObject, HistoryStoreProtocol {

    // MARK: - Published State

    @Published private(set) var entries: [TranslationEntry] = []

    var entriesPublisher: AnyPublisher<[TranslationEntry], Never> {
        $entries.eraseToAnyPublisher()
    }

    // MARK: - Configuration

    /// Maximum number of entries to keep in history
    let maxEntries: Int

    /// Storage key for UserDefaults
    private let storageKey = "com.aitranslate.history.v1"

    /// UserDefaults instance (injectable for testing)
    private let userDefaults: UserDefaults

    // MARK: - Singleton

    static let shared = HistoryStore()

    // MARK: - Initialization

    /// Creates a new HistoryStore
    /// - Parameters:
    ///   - maxEntries: Maximum entries to retain (default 100)
    ///   - userDefaults: UserDefaults instance for persistence
    init(maxEntries: Int = 100, userDefaults: UserDefaults = .standard) {
        self.maxEntries = maxEntries
        self.userDefaults = userDefaults
        loadFromStorage()
    }

    // MARK: - CRUD Operations

    func add(_ entry: TranslationEntry) {
        // Remove duplicate if exists (same source/target text and languages)
        // This moves the entry to the top instead of creating duplicates
        entries.removeAll { existing in
            existing.sourceText == entry.sourceText &&
            existing.targetLanguage == entry.targetLanguage &&
            existing.effectiveSourceLanguage == entry.effectiveSourceLanguage
        }

        // Insert at beginning (most recent first)
        entries.insert(entry, at: 0)

        // Trim to max entries, but preserve favorites
        trimToMaxEntries()

        saveToStorage()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        saveToStorage()
    }

    func removeMultiple(ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        saveToStorage()
    }

    func clearAll() {
        entries.removeAll()
        saveToStorage()
    }

    func clearHistory(keepFavorites: Bool = true) {
        if keepFavorites {
            entries = entries.filter { $0.isFavorite }
        } else {
            entries.removeAll()
        }
        saveToStorage()
    }

    func toggleFavorite(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isFavorite.toggle()
        saveToStorage()
    }

    func update(_ entry: TranslationEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        saveToStorage()
    }

    func find(id: UUID) -> TranslationEntry? {
        entries.first { $0.id == id }
    }

    // MARK: - Filtered Views

    /// All entries marked as favorite
    var favorites: [TranslationEntry] {
        entries.filter { $0.isFavorite }
    }

    /// Number of favorites
    var favoritesCount: Int {
        entries.count { $0.isFavorite }
    }

    /// Number of non-favorite entries
    var historyCount: Int {
        entries.count { !$0.isFavorite }
    }

    /// Recent entries (last 10)
    var recentEntries: [TranslationEntry] {
        Array(entries.prefix(10))
    }

    /// Search entries by text content
    /// - Parameter query: Search query
    /// - Returns: Matching entries
    func search(query: String) -> [TranslationEntry] {
        guard !query.isEmpty else { return entries }
        let lowercased = query.lowercased()
        return entries.filter {
            $0.sourceText.lowercased().contains(lowercased) ||
            $0.translatedText.lowercased().contains(lowercased)
        }
    }

    /// Search within favorites only
    func searchFavorites(query: String) -> [TranslationEntry] {
        guard !query.isEmpty else { return favorites }
        let lowercased = query.lowercased()
        return favorites.filter {
            $0.sourceText.lowercased().contains(lowercased) ||
            $0.translatedText.lowercased().contains(lowercased)
        }
    }

    /// Filter entries by language pair
    func filter(sourceLanguage: String?, targetLanguage: String?) -> [TranslationEntry] {
        entries.filter { entry in
            let matchesSource = sourceLanguage == nil ||
                entry.effectiveSourceLanguage == sourceLanguage
            let matchesTarget = targetLanguage == nil ||
                entry.targetLanguage == targetLanguage
            return matchesSource && matchesTarget
        }
    }

    // MARK: - Offline Translation Cache

    /// Looks up a cached translation for the given text and language pair.
    /// Enables offline translation lookup for previously translated content.
    func findCachedTranslation(
        text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> TranslationEntry? {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return entries.first { entry in
            let textMatches = entry.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedText
            let targetMatches = entry.targetLanguage == targetLanguage
            let sourceMatches = sourceLanguage == "auto" || entry.effectiveSourceLanguage == sourceLanguage
            return textMatches && targetMatches && sourceMatches
        }
    }

    /// Checks if a translation is available in the cache
    func hasCachedTranslation(text: String, sourceLanguage: String, targetLanguage: String) -> Bool {
        findCachedTranslation(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) != nil
    }

    /// Returns the approximate size of the cache in bytes
    var cacheSize: Int {
        guard let data = userDefaults.data(forKey: storageKey) else { return 0 }
        return data.count
    }

    /// Returns a formatted string for the cache size
    var cacheSizeFormatted: String {
        let bytes = cacheSize
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Clears cache entries (non-favorites) older than specified days
    func clearOldCache(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        entries.removeAll { entry in
            !entry.isFavorite && entry.createdAt < cutoffDate
        }
        saveToStorage()
    }

    /// Clears all non-favorite entries (cache only)
    func clearCache() {
        entries.removeAll { !$0.isFavorite }
        saveToStorage()
    }

    /// Group entries by date
    func groupedByDate() -> [(date: Date, entries: [TranslationEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, entries: $0.value) }
    }

    // MARK: - Private Methods

    private func trimToMaxEntries() {
        guard entries.count > maxEntries else { return }

        // Separate favorites and non-favorites
        let favoriteEntries = entries.filter { $0.isFavorite }
        var nonFavoriteEntries = entries.filter { !$0.isFavorite }

        // Calculate how many non-favorites we can keep
        let maxNonFavorites = max(0, maxEntries - favoriteEntries.count)

        // Trim non-favorites (they're already sorted by recency)
        if nonFavoriteEntries.count > maxNonFavorites {
            nonFavoriteEntries = Array(nonFavoriteEntries.prefix(maxNonFavorites))
        }

        // Rebuild entries maintaining order
        entries = entries.filter { entry in
            entry.isFavorite || nonFavoriteEntries.contains { $0.id == entry.id }
        }
    }

    private func loadFromStorage() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            // Try migrating from old key if exists
            migrateFromOldStorage()
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([TranslationEntry].self, from: data)
        } catch {
            #if DEBUG
            print("[HistoryStore] Failed to load: \(error)")
            #endif
            entries = []
        }
    }

    private func migrateFromOldStorage() {
        let oldKey = "com.aitranslate.history"
        guard let data = userDefaults.data(forKey: oldKey) else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([TranslationEntry].self, from: data)
            // Save to new key and remove old
            saveToStorage()
            userDefaults.removeObject(forKey: oldKey)
            #if DEBUG
            print("[HistoryStore] Migrated \(entries.count) entries from old storage")
            #endif
        } catch {
            #if DEBUG
            print("[HistoryStore] Migration failed: \(error)")
            #endif
        }
    }

    private func saveToStorage() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            #if DEBUG
            print("[HistoryStore] Failed to save: \(error)")
            #endif
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension HistoryStore {
    static var preview: HistoryStore {
        let store = HistoryStore(userDefaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)")!)

        // Add sample entries
        let sampleEntries: [TranslationEntry] = [
            TranslationEntry(
                sourceText: "Hello, how are you?",
                translatedText: "Hola, ¿cómo estás?",
                sourceLanguage: "en",
                targetLanguage: "es",
                createdAt: Date().addingTimeInterval(-3600),
                isFavorite: true
            ),
            TranslationEntry(
                sourceText: "Good morning",
                translatedText: "Bonjour",
                sourceLanguage: "en",
                targetLanguage: "fr",
                createdAt: Date().addingTimeInterval(-7200),
                isFavorite: false
            ),
            TranslationEntry(
                sourceText: "Thank you very much",
                translatedText: "Vielen Dank",
                sourceLanguage: "en",
                targetLanguage: "de",
                createdAt: Date().addingTimeInterval(-86400),
                isFavorite: true
            ),
            TranslationEntry(
                sourceText: "Where is the restaurant?",
                translatedText: "Dove è il ristorante?",
                sourceLanguage: "en",
                targetLanguage: "it",
                createdAt: Date().addingTimeInterval(-86400 * 2),
                isFavorite: false
            ),
            TranslationEntry(
                sourceText: "I love this app",
                translatedText: "私はこのアプリが大好きです",
                sourceLanguage: "en",
                targetLanguage: "ja",
                createdAt: Date().addingTimeInterval(-86400 * 3),
                isFavorite: false
            ),
        ]

        sampleEntries.reversed().forEach { store.add($0) }
        return store
    }

    static var previewEmpty: HistoryStore {
        HistoryStore(userDefaults: UserDefaults(suiteName: "preview.empty.\(UUID().uuidString)")!)
    }
}
#endif
