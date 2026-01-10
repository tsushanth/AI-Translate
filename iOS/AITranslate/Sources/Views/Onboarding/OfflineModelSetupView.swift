import SwiftUI

/// View for selecting and downloading offline AI models during onboarding
struct OfflineModelSetupView: View {
    @State private var selectedPackage: OfflineModelPackage?
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var downloadComplete: Bool = false

    let deviceCapability: OfflineCapability
    let onContinue: (OfflineModelPackage?) -> Void

    private var availablePackages: [OfflineModelPackage] {
        DeviceCapabilityChecker.shared.getAvailablePackages()
    }

    private var recommendedPackage: OfflineModelPackage? {
        DeviceCapabilityChecker.shared.getRecommendedPackage()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Device info
                    deviceInfoCard

                    // Package options
                    packageSelectionSection

                    // Performance note for standard support devices
                    if deviceCapability == .standardSupport {
                        performanceNoteCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            // Bottom action section
            bottomActionSection
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .blur(radius: 15)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Download Offline Models")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Choose how much offline capability you want. You can always change this later in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Device Info Card

    private var deviceInfoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(DeviceCapabilityChecker.shared.deviceName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(deviceCapability.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Capability badge
            Text(deviceCapability.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(deviceCapability == .fullSupport ? Color.green : Color.orange)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Package Selection Section

    private var packageSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select a Package")
                .font(.headline)

            ForEach(availablePackages, id: \.id) { package in
                PackageOptionCard(
                    package: package,
                    isSelected: selectedPackage == package,
                    isRecommended: package == recommendedPackage,
                    deviceCapability: deviceCapability
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPackage = package
                    }
                }
            }
        }
    }

    // MARK: - Performance Note Card

    private var performanceNoteCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Performance Note")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("On your device, speech processing may take longer than real-time. For faster results, consider the Essential package.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Bottom Action Section

    private var bottomActionSection: some View {
        VStack(spacing: 12) {
            // Download/Continue button
            Button {
                handleContinue()
            } label: {
                HStack(spacing: 8) {
                    if isDownloading {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedPackage != nil ? Color.blue : Color.gray)
                )
            }
            .disabled(selectedPackage == nil || isDownloading)

            // Size info
            if let package = selectedPackage, package != .none {
                Text("Download size: \(package.totalSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    private var buttonTitle: String {
        if isDownloading {
            return "Downloading..."
        }

        guard let package = selectedPackage else {
            return "Select a Package"
        }

        if package == .none {
            return "Continue Without Downloading"
        }

        return "Download & Continue"
    }

    private func handleContinue() {
        guard let package = selectedPackage else { return }

        if package == .none {
            // Skip download
            onContinue(nil)
        } else {
            // Start download
            isDownloading = true

            // For now, just simulate download and continue
            // Real implementation will use OfflineModelManager
            Task {
                // Simulate download delay for demo
                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    isDownloading = false
                    onContinue(package)
                }
            }
        }
    }
}

// MARK: - Package Option Card

struct PackageOptionCard: View {
    let package: OfflineModelPackage
    let isSelected: Bool
    let isRecommended: Bool
    let deviceCapability: OfflineCapability
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    // Title row
                    HStack {
                        Text(package.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                        }

                        Spacer()

                        Text(package.totalSize)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Features list
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(package.features, id: \.self) { feature in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundStyle(.green)

                                Text(feature)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Performance estimate for non-skip options
                    if package != .none, let whisperModel = package.whisperModel {
                        let estimate = DeviceCapabilityChecker.shared.getPerformanceEstimate(for: whisperModel)
                        HStack(spacing: 4) {
                            Image(systemName: estimate.statusIcon)
                                .font(.caption)
                                .foregroundStyle(estimateColor(for: estimate))

                            Text("Speed: \(estimate.displayText)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func estimateColor(for estimate: PerformanceEstimate) -> Color {
        switch estimate.statusColor {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Offline Setup - Full Support") {
    OfflineModelSetupView(
        deviceCapability: .fullSupport,
        onContinue: { _ in }
    )
}

#Preview("Offline Setup - Standard Support") {
    OfflineModelSetupView(
        deviceCapability: .standardSupport,
        onContinue: { _ in }
    )
}
#endif
