import SwiftUI

/// A row displaying a translation history entry
struct HistoryRowView: View {
    let entry: TranslationEntry
    let isSelected: Bool
    let isSpeaking: Bool
    let isEditing: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onSpeak: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox (edit mode)
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }

            // Main content
            VStack(alignment: .leading, spacing: 6) {
                // Language pair header
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
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                // Translated text
                Text(entry.translatedText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Action buttons (non-edit mode)
            if !isEditing {
                HStack(spacing: 8) {
                    // Speak button
                    Button(action: onSpeak) {
                        Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.body)
                            .foregroundStyle(isSpeaking ? Color.accentColor : .secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    // Favorite button
                    Button(action: onFavorite) {
                        Image(systemName: entry.isFavorite ? "star.fill" : "star")
                            .font(.body)
                            .foregroundStyle(entry.isFavorite ? .yellow : .secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

/// Compact row for use in search results or suggestions
struct HistoryCompactRowView: View {
    let entry: TranslationEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.sourceText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(entry.translatedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Language badge
                Text("\(entry.sourceLanguageDisplay) → \(entry.targetLanguageDisplay)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(4)

                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("History Row - Normal") {
    List {
        HistoryRowView(
            entry: .preview,
            isSelected: false,
            isSpeaking: false,
            isEditing: false,
            onTap: {},
            onFavorite: {},
            onSpeak: {},
            onDelete: {}
        )

        HistoryRowView(
            entry: .previewFavorite,
            isSelected: false,
            isSpeaking: false,
            isEditing: false,
            onTap: {},
            onFavorite: {},
            onSpeak: {},
            onDelete: {}
        )

        HistoryRowView(
            entry: .preview,
            isSelected: false,
            isSpeaking: true,
            isEditing: false,
            onTap: {},
            onFavorite: {},
            onSpeak: {},
            onDelete: {}
        )
    }
}

#Preview("History Row - Edit Mode") {
    List {
        HistoryRowView(
            entry: .preview,
            isSelected: false,
            isSpeaking: false,
            isEditing: true,
            onTap: {},
            onFavorite: {},
            onSpeak: {},
            onDelete: {}
        )

        HistoryRowView(
            entry: .previewFavorite,
            isSelected: true,
            isSpeaking: false,
            isEditing: true,
            onTap: {},
            onFavorite: {},
            onSpeak: {},
            onDelete: {}
        )
    }
}

#Preview("Compact Row") {
    List {
        HistoryCompactRowView(entry: .preview, onTap: {})
        HistoryCompactRowView(entry: .previewFavorite, onTap: {})
    }
}
#endif
