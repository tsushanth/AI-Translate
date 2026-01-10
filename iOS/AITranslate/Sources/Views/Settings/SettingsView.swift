import SwiftUI

/// Settings view for app configuration (More tab)
struct SettingsView: View {

    @Bindable private var settings = SettingsStore.shared
    @ObservedObject private var historyStore = HistoryStore.shared
    @State private var showClearHistoryConfirmation = false
    @State private var showDeleteModelsConfirmation = false

    private let deviceCapability = DeviceCapabilityChecker.shared.offlineCapability
    private let modelManager = OfflineModelManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Offline Models Section (only for supported devices)
                if deviceCapability.supportsOfflineMode {
                    offlineModelsSection
                }

                // History Section
                Section {
                    NavigationLink {
                        HistoryListView(historyStore: historyStore)
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            Text("Translation History")
                            Spacer()
                            if historyStore.entries.count > 0 {
                                Text("\(historyStore.entries.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        FavoritesListView(historyStore: historyStore)
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .frame(width: 28)
                            Text("Favorites")
                            Spacer()
                            if historyStore.favoritesCount > 0 {
                                Text("\(historyStore.favoritesCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appColorScheme) {
                        ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                            Text(scheme.displayName).tag(scheme)
                        }
                    }
                }

                // Translation Provider Section
                Section {
                    ForEach(TranslationProviderType.allCases, id: \.self) { provider in
                        ProviderRow(
                            provider: provider,
                            isSelected: settings.translationProvider == provider
                        ) {
                            settings.translationProvider = provider
                        }
                    }
                } header: {
                    Text("Translation Engine")
                } footer: {
                    Text("Choose which translation service to use. Google is faster, DeepL may have more natural phrasing.")
                }

                // Preferences Section
                Section("Preferences") {
                    Toggle("Auto-detect Language", isOn: $settings.autoDetectLanguage)
                    Toggle("Haptic Feedback", isOn: $settings.hapticFeedback)
                }

                // Data Section
                Section("Data") {
                    Button(role: .destructive) {
                        showClearHistoryConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .frame(width: 28)
                            Text("Clear All History")
                        }
                    }
                    .disabled(historyStore.entries.isEmpty)
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://kreativekoala.llc/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://kreativekoala.llc/terms")!) {
                        HStack {
                            Text("Terms of Service")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://kreativekoala.llc/contact")!) {
                        HStack {
                            Text("Contact Us")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Clear All History",
                isPresented: $showClearHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    historyStore.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all translation history and favorites. This action cannot be undone.")
            }
            .confirmationDialog(
                "Delete Offline Models",
                isPresented: $showDeleteModelsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All Models", role: .destructive) {
                    Task {
                        try? await modelManager.deleteAllModels()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all downloaded offline models (\(modelManager.totalDownloadedSizeFormatted())). You can re-download them anytime.")
            }
        }
    }

    // MARK: - Offline Models Section

    @ViewBuilder
    private var offlineModelsSection: some View {
        Section {
            // Device info
            HStack {
                Image(systemName: "iphone")
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(DeviceCapabilityChecker.shared.deviceName)
                        .font(.subheadline)
                    Text(deviceCapability.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(deviceCapability.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(deviceCapability == .fullSupport ? Color.green : Color.orange)
                    )
            }

            // Downloaded models
            NavigationLink {
                OfflineModelsDetailView()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Offline Models")
                        if let package = modelManager.downloadedPackage {
                            Text("\(package.displayName) - \(modelManager.totalDownloadedSizeFormatted())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not downloaded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if modelManager.downloadedPackage != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            // Delete models button
            if modelManager.downloadedPackage != nil {
                Button(role: .destructive) {
                    showDeleteModelsConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .frame(width: 28)
                        Text("Delete Offline Models")
                    }
                }
            }
        } header: {
            Text("Offline Mode")
        } footer: {
            Text("Download AI models to use translation features without internet. Free users can use offline features.")
        }

        // TTS Mode Section
        Section {
            Picker("Voice Mode", selection: Binding(
                get: { TTSManager.shared.currentMode },
                set: { TTSManager.shared.setMode($0) }
            )) {
                ForEach(TTSManager.shared.availableModes) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                    }
                    .tag(mode)
                }
            }
        } header: {
            Text("Text-to-Speech")
        } footer: {
            Text(TTSManager.shared.currentMode.description)
        }
    }
}

// MARK: - Provider Row

private struct ProviderRow: View {
    let provider: TranslationProviderType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .foregroundStyle(.primary)
                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History List View

struct HistoryListView: View {
    @ObservedObject var historyStore: HistoryStore
    @State private var searchText = ""

    var filteredEntries: [TranslationEntry] {
        if searchText.isEmpty {
            return historyStore.entries
        }
        return historyStore.entries.filter { entry in
            entry.sourceText.localizedCaseInsensitiveContains(searchText) ||
            entry.translatedText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(filteredEntries) { entry in
                HistoryEntryRow(entry: entry) {
                    historyStore.toggleFavorite(id: entry.id)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let entry = filteredEntries[index]
                    historyStore.remove(id: entry.id)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search history")
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No History" : "No Results",
                    systemImage: searchText.isEmpty ? "clock" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Your translation history will appear here" : "Try a different search term")
                )
            }
        }
    }
}

// MARK: - Favorites List View

struct FavoritesListView: View {
    @ObservedObject var historyStore: HistoryStore

    var favorites: [TranslationEntry] {
        historyStore.entries.filter { $0.isFavorite }
    }

    var body: some View {
        List {
            ForEach(favorites) { entry in
                HistoryEntryRow(entry: entry) {
                    historyStore.toggleFavorite(id: entry.id)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let entry = favorites[index]
                    historyStore.toggleFavorite(id: entry.id)
                }
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Tap the heart icon on any translation to add it to favorites")
                )
            }
        }
    }
}

// MARK: - History Entry Row

struct HistoryEntryRow: View {
    let entry: TranslationEntry
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Language pair
            HStack(spacing: 4) {
                Text(entry.sourceLanguageDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(entry.targetLanguageDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Source text
            Text(entry.sourceText)
                .font(.subheadline)
                .lineLimit(2)

            // Translation
            Text(entry.translatedText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Actions
            HStack {
                Spacer()
                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: entry.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(entry.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
}
