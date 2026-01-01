import SwiftUI

/// Circular action button with icon
struct ActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        icon: String,
        label: String,
        isActive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(isActive ? Color.accentColor : Color(.tertiarySystemBackground))
                    .foregroundStyle(isActive ? .white : (isDisabled ? Color.gray : .primary))
                    .clipShape(Circle())

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isDisabled ? Color.gray : .secondary)
            }
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

/// Microphone button with recording state
struct MicrophoneButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 64, height: 64)

                if isRecording {
                    // Stop icon
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 20, height: 20)
                } else {
                    // Mic icon
                    Image(systemName: "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .shadow(color: (isRecording ? Color.red : Color.accentColor).opacity(0.3),
                radius: 8, x: 0, y: 4)
    }
}

/// Speaker button with playing state
struct SpeakerButton: View {
    let isSpeaking: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        ActionButton(
            icon: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill",
            label: isSpeaking ? "Stop" : "Listen",
            isActive: isSpeaking,
            isDisabled: isDisabled,
            action: action
        )
    }
}

/// Favorite/star button
struct FavoriteButton: View {
    let isFavorite: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.title2)
                .foregroundStyle(isFavorite ? .yellow : (isDisabled ? Color.gray : .primary))
                .frame(width: 44, height: 44)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

/// Swap languages button
struct SwapLanguagesButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.title3)
                .foregroundStyle(isDisabled ? Color.gray : .primary)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Circle())
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

/// Copy button
struct CopyButton: View {
    let isDisabled: Bool
    let action: () -> Void

    @State private var showCopied = false

    var body: some View {
        Button {
            action()
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCopied = false
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                if showCopied {
                    Text("Copied")
                        .font(.caption)
                }
            }
            .foregroundStyle(showCopied ? .green : (isDisabled ? Color.gray : .secondary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(6)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: showCopied)
    }
}

/// Translate button
struct TranslateButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                }
                Text(isLoading ? "Translating..." : "Translate")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isDisabled ? Color.gray : Color.accentColor)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Action Buttons") {
    HStack(spacing: 20) {
        ActionButton(icon: "speaker.wave.2", label: "Listen") {}
        ActionButton(icon: "star", label: "Favorite") {}
        ActionButton(icon: "doc.on.doc", label: "Copy") {}
        ActionButton(icon: "speaker.wave.2", label: "Active", isActive: true) {}
        ActionButton(icon: "speaker.wave.2", label: "Disabled", isDisabled: true) {}
    }
    .padding()
}

#Preview("Microphone Button") {
    HStack(spacing: 40) {
        MicrophoneButton(isRecording: false) {}
        MicrophoneButton(isRecording: true) {}
    }
    .padding()
}

#Preview("Speaker Button") {
    HStack(spacing: 20) {
        SpeakerButton(isSpeaking: false, isDisabled: false) {}
        SpeakerButton(isSpeaking: true, isDisabled: false) {}
        SpeakerButton(isSpeaking: false, isDisabled: true) {}
    }
    .padding()
}

#Preview("Favorite Button") {
    HStack(spacing: 20) {
        FavoriteButton(isFavorite: false, isDisabled: false) {}
        FavoriteButton(isFavorite: true, isDisabled: false) {}
        FavoriteButton(isFavorite: false, isDisabled: true) {}
    }
    .padding()
}

#Preview("Translate Button") {
    VStack(spacing: 16) {
        TranslateButton(isLoading: false, isDisabled: false) {}
        TranslateButton(isLoading: true, isDisabled: false) {}
        TranslateButton(isLoading: false, isDisabled: true) {}
    }
    .padding()
}

#Preview("Copy Button") {
    HStack(spacing: 16) {
        CopyButton(isDisabled: false) {}
        CopyButton(isDisabled: true) {}
    }
    .padding()
}
#endif
