import SwiftUI

/// Overlay shown when a feature requires internet but device is offline
struct OfflineUnavailableOverlay: View {
    let feature: String
    let suggestion: String

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Icon
                Image(systemName: "wifi.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                // Title
                Text("\(feature) Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                // Description
                Text("This feature requires an internet connection.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                // Suggestion
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            }
            .padding(32)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Offline Overlay - Text") {
    OfflineUnavailableOverlay(
        feature: "Text Translation",
        suggestion: "Use Voice tab for offline translation"
    )
}

#Preview("Offline Overlay - Camera") {
    OfflineUnavailableOverlay(
        feature: "Camera Translation",
        suggestion: "Use Voice tab for offline translation"
    )
}
#endif
