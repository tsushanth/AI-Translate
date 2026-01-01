import SwiftUI

/// Text editor for source text input
struct SourceTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let isRecording: Bool
    var onClear: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty && !isFocused {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
            }

            // Text editor
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100, maxHeight: 150)

            // Recording indicator
            if isRecording {
                HStack {
                    Spacer()
                    RecordingIndicator()
                        .padding(8)
                }
            }

            // Clear button
            if !text.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            onClear?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Display view for translated text
struct TranslatedTextView: View {
    let text: String
    let isLoading: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 4)
                    Text("Translating...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if text.isEmpty {
                Text("Translation will appear here")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(minHeight: 100, maxHeight: 150)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

/// Animated recording indicator
struct RecordingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .opacity(isAnimating ? 0.3 : 1.0)

            Text("Listening...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Source Text Editor - Empty") {
    struct PreviewWrapper: View {
        @State private var text = ""

        var body: some View {
            SourceTextEditor(
                text: $text,
                placeholder: "Enter text to translate",
                isRecording: false
            )
            .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("Source Text Editor - With Text") {
    struct PreviewWrapper: View {
        @State private var text = "Hello, how are you today?"

        var body: some View {
            SourceTextEditor(
                text: $text,
                placeholder: "Enter text to translate",
                isRecording: false
            ) {
                text = ""
            }
            .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("Source Text Editor - Recording") {
    struct PreviewWrapper: View {
        @State private var text = "Hello..."

        var body: some View {
            SourceTextEditor(
                text: $text,
                placeholder: "Enter text to translate",
                isRecording: true
            )
            .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("Translated Text View - Empty") {
    TranslatedTextView(text: "", isLoading: false)
        .padding()
}

#Preview("Translated Text View - Loading") {
    TranslatedTextView(text: "", isLoading: true)
        .padding()
}

#Preview("Translated Text View - With Text") {
    TranslatedTextView(
        text: "Hola, ¿cómo estás hoy?",
        isLoading: false
    )
    .padding()
}
#endif
