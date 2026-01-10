import SwiftUI

/// Detailed view for managing offline AI models
struct OfflineModelsDetailView: View {

    private let deviceCapability = DeviceCapabilityChecker.shared.offlineCapability
    @State private var modelManager = OfflineModelManager.shared

    @State private var downloadError: String?
    @State private var showError: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var selectedPackageForDownload: OfflineModelPackage?

    /// Languages supported by Apple Translation (for display)
    private let supportedLanguages = [
        "Arabic", "Chinese", "Dutch", "English",
        "French", "German", "Hindi", "Indonesian",
        "Italian", "Japanese", "Korean", "Polish",
        "Portuguese", "Russian", "Spanish", "Thai",
        "Turkish", "Ukrainian", "Vietnamese"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Status Card
                currentStatusCard

                // Package Comparison
                packageComparisonSection

                // Apple Translation Info (for Full Offline / Maximum Quality)
                if modelManager.downloadedPackage?.includesAppleTranslation == true {
                    appleTranslationCard
                }

                // Delete Section
                if modelManager.downloadedPackage != nil {
                    deleteSection
                }
            }
            .padding()
        }
        .navigationTitle("Offline Models")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .alert("Download Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(downloadError ?? "An error occurred while downloading.")
        }
        .confirmationDialog(
            "Delete Offline Models",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Models", role: .destructive) {
                Task {
                    try? await modelManager.deleteAllModels()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all downloaded offline models. You can re-download them anytime.")
        }
    }

    // MARK: - Current Status Card

    private var currentStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let package = modelManager.downloadedPackage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Currently Installed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(package.displayName)
                            .font(.headline)
                    }

                    Spacer()

                    Text(modelManager.totalDownloadedSizeFormatted())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Features list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(package.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(feature)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            } else {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.blue)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Package Installed")
                            .font(.headline)
                        Text("Choose a package below to enable offline features")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Package Comparison Section

    private var packageComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a Package")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(DeviceCapabilityChecker.shared.getAvailablePackages().filter { $0 != .none }, id: \.id) { package in
                PackageComparisonCard(
                    package: package,
                    isDownloaded: modelManager.downloadedPackage == package,
                    isRecommended: package == DeviceCapabilityChecker.shared.getRecommendedPackage(),
                    downloadProgress: modelManager.currentlyDownloading == package ? modelManager.downloadProgress : nil,
                    onDownload: {
                        Task {
                            await downloadPackage(package)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Apple Translation Card

    private var appleTranslationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(.blue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Translation")
                        .font(.headline)
                    Text("Multi-language offline translation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text("Your package includes access to Apple's built-in translation. Follow these steps to download languages for offline use:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Step-by-step instructions
            VStack(alignment: .leading, spacing: 12) {
                InstructionStep(number: 1, text: "Open the **Settings** app on your iPhone")
                InstructionStep(number: 2, text: "Scroll down and tap **Apps**")
                InstructionStep(number: 3, text: "Tap **Translate**")
                InstructionStep(number: 4, text: "Tap **Downloaded Languages**")
                InstructionStep(number: 5, text: "Tap the download button next to each language you want")
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Alternative: Open Translate app directly
            Button {
                // Try to open the Translate app
                if let url = URL(string: "translate://") {
                    UIApplication.shared.open(url) { success in
                        if !success {
                            // Translate app not installed, open App Store
                            if let appStoreURL = URL(string: "https://apps.apple.com/app/translate/id1514844618") {
                                UIApplication.shared.open(appStoreURL)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "character.bubble")
                    Text("Open Translate App")
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Supported languages
            VStack(alignment: .leading, spacing: 8) {
                Text("Supported Languages")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // Language grid for better scanning
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                    ForEach(supportedLanguages, id: \.self) { language in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text(language)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete All Offline Models")
                Spacer()
                Text(modelManager.totalDownloadedSizeFormatted())
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private func downloadPackage(_ package: OfflineModelPackage) async {
        do {
            try await modelManager.downloadPackage(package)
        } catch {
            downloadError = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Package Comparison Card

private struct PackageComparisonCard: View {
    let package: OfflineModelPackage
    let isDownloaded: Bool
    let isRecommended: Bool
    let downloadProgress: Double?
    let onDownload: () -> Void

    @State private var showAllLanguages: Bool = false

    /// All supported Apple Translation languages
    private let allSupportedLanguages = [
        "Arabic", "Chinese", "Dutch", "English",
        "French", "German", "Hindi", "Indonesian",
        "Italian", "Japanese", "Korean", "Polish",
        "Portuguese", "Russian", "Spanish", "Thai",
        "Turkish", "Ukrainian", "Vietnamese"
    ]

    private var isDownloading: Bool {
        downloadProgress != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                // Icon
                ZStack {
                    Circle()
                        .fill(packageColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: packageIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(packageColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Title row
                    HStack(spacing: 8) {
                        Text(package.displayName)
                            .font(.headline)

                        if isRecommended && !isDownloaded {
                            Text("BEST VALUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.green))
                        }

                        if isDownloaded {
                            Text("INSTALLED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.blue))
                        }
                    }

                    // Size
                    Text(package.totalSize)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()

            Divider()
                .padding(.horizontal)

            // Features comparison
            VStack(alignment: .leading, spacing: 10) {
                // Speech Recognition
                FeatureRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    value: speechRecognitionValue,
                    valueColor: speechRecognitionColor
                )

                // Languages - expandable for multi-language packages
                if package.includesAppleTranslation {
                    ExpandableLanguageRow(
                        isExpanded: $showAllLanguages,
                        languages: allSupportedLanguages
                    )
                } else {
                    FeatureRow(
                        icon: "globe",
                        title: "Translate To",
                        value: translationValue,
                        valueColor: translationColor
                    )
                }

                // Speed
                FeatureRow(
                    icon: "speedometer",
                    title: "Processing Speed",
                    value: speedValue,
                    valueColor: .primary
                )

                // Offline
                FeatureRow(
                    icon: "wifi.slash",
                    title: "Works Offline",
                    value: "Yes",
                    valueColor: .green
                )
            }
            .padding()

            // Download button or progress
            if !isDownloaded {
                Divider()
                    .padding(.horizontal)

                if isDownloading, let progress = downloadProgress {
                    // Progress view
                    VStack(spacing: 8) {
                        HStack {
                            Text("Downloading...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }

                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                    }
                    .padding()
                } else {
                    Button(action: onDownload) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Package")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(packageColor)
                    .padding()
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDownloaded ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - Computed Properties

    private var packageColor: Color {
        switch package {
        case .essential: return .blue
        case .standard: return .green
        case .fullOffline: return .orange
        case .maximumQuality: return .purple
        case .none: return .gray
        }
    }

    private var packageIcon: String {
        switch package {
        case .essential: return "bolt.fill"
        case .standard: return "star.fill"
        case .fullOffline: return "globe"
        case .maximumQuality: return "crown.fill"
        case .none: return "xmark"
        }
    }

    private var speechRecognitionValue: String {
        switch package {
        case .essential: return "Basic"
        case .standard: return "Good"
        case .fullOffline: return "Good"
        case .maximumQuality: return "Best"
        case .none: return "None"
        }
    }

    private var speechRecognitionColor: Color {
        switch package {
        case .essential: return .orange
        case .standard, .fullOffline: return .green
        case .maximumQuality: return .purple
        case .none: return .red
        }
    }

    private var translationValue: String {
        switch package {
        case .essential, .standard: return "English only"
        case .fullOffline, .maximumQuality: return "Spanish, French, Chinese, Japanese, Korean & more"
        case .none: return "None"
        }
    }

    private var translationColor: Color {
        switch package {
        case .essential, .standard: return .orange
        case .fullOffline, .maximumQuality: return .green
        case .none: return .red
        }
    }

    private var speedValue: String {
        switch package {
        case .essential: return "Fastest"
        case .standard, .fullOffline: return "Fast"
        case .maximumQuality: return "Moderate"
        case .none: return "N/A"
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Expandable Language Row

private struct ExpandableLanguageRow: View {
    @Binding var isExpanded: Bool
    let languages: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row - tappable
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text("Translate To")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text(isExpanded ? "19 languages" : "Spanish, French, Chinese & more")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.plain)

            // Expanded language grid
            if isExpanded {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                    ForEach(languages, id: \.self) { language in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text(language)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 28) // Align with text after icon
            }
        }
    }
}

// MARK: - Instruction Step

private struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))

            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        OfflineModelsDetailView()
    }
}
