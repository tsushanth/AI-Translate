import SwiftUI

/// Voice conversation translation view
@MainActor
struct VoiceConversationView: View {
    @StateObject private var viewModel = VoiceConversationViewModel()
    @State private var showLanguageSettings = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Conversation messages
                conversationList

                // Bottom controls
                bottomControls
            }
        }
        .sheet(isPresented: $showLanguageSettings) {
            VoiceLanguageSettingsView(
                leftLanguage: $viewModel.leftLanguage,
                rightLanguage: $viewModel.rightLanguage
            )
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Microphone Access Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow microphone access in Settings to use voice translation.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("AI Translate")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Spacer()

            // Recording indicator
            if viewModel.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isRecording)
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.red)
                    Text("Recording")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.red.opacity(0.2)))
            } else if viewModel.isSpeaking {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.blue)
                    Text("Speaking")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.blue.opacity(0.2)))
            }

            Spacer()

            // Settings button
            Button {
                showLanguageSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ConversationBubble(message: message)
                            .id(message.id)
                    }

                    // Listening indicator
                    if viewModel.isRecording {
                        listeningIndicator
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var listeningIndicator: some View {
        HStack(spacing: 8) {
            // Animated microphone icon
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(.red)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)

            VStack(alignment: .leading, spacing: 2) {
                Text("Listening...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                Text("Speak in \(viewModel.currentRecordingLanguage == .left ? viewModel.leftLanguage.displayName : viewModel.rightLanguage.displayName)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.15))
        )
        .padding(.horizontal)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 40) {
            // Left language button (tap to record in this language)
            LanguageRecordButton(
                language: viewModel.leftLanguage,
                isRecording: viewModel.isRecording && viewModel.currentRecordingLanguage == .left,
                isDisabled: viewModel.isRecording && viewModel.currentRecordingLanguage != .left
            ) {
                Task {
                    await viewModel.toggleRecording(for: .left)
                }
            }

            // Clear/stop button
            Button {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.clearConversation()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.gray.opacity(0.3)))
            }

            // Right language button (tap to record in this language)
            LanguageRecordButton(
                language: viewModel.rightLanguage,
                isRecording: viewModel.isRecording && viewModel.currentRecordingLanguage == .right,
                isDisabled: viewModel.isRecording && viewModel.currentRecordingLanguage != .right
            ) {
                Task {
                    await viewModel.toggleRecording(for: .right)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .background(Color.black)
    }
}

// MARK: - Language Record Button

struct LanguageRecordButton: View {
    let language: Language
    let isRecording: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Pulsing animation when recording
                    if isRecording {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .scaleEffect(isRecording ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
                    }

                    // Flag circle
                    Circle()
                        .fill(isRecording ? Color.red : Color.white.opacity(0.1))
                        .frame(width: 80, height: 80)

                    if isRecording {
                        // Stop icon (square) when recording
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                    } else {
                        // Flag emoji when not recording
                        Text(language.flagEmoji)
                            .font(.system(size: 44))
                    }

                    // Recording indicator ring
                    if isRecording {
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 90, height: 90)
                    }
                }

                // Label
                Text(isRecording ? "Tap to Stop" : language.displayName)
                    .font(.caption)
                    .foregroundStyle(isRecording ? .red : .white.opacity(0.7))
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

// MARK: - Conversation Bubble

struct ConversationBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.side == .right {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.side == .left ? .leading : .trailing, spacing: 4) {
                // Original text
                Text(message.originalText)
                    .font(.body)
                    .foregroundStyle(.white)

                // Translation
                Text(message.translatedText)
                    .font(.body)
                    .foregroundStyle(.cyan)

                // Word type indicator (if available)
                if let wordType = message.wordType {
                    HStack(spacing: 4) {
                        Text(wordType)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray.opacity(0.3)))

                        Text(message.additionalInfo ?? "")
                            .font(.caption)
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                }
            }

            if message.side == .left {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Voice Language Settings

struct VoiceLanguageSettingsView: View {
    @Binding var leftLanguage: Language
    @Binding var rightLanguage: Language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Left Speaker") {
                    ForEach(Language.targetLanguages, id: \.code) { language in
                        Button {
                            leftLanguage = language
                        } label: {
                            HStack {
                                Text(language.flagEmoji)
                                Text(language.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if leftLanguage.code == language.code {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                Section("Right Speaker") {
                    ForEach(Language.targetLanguages, id: \.code) { language in
                        Button {
                            rightLanguage = language
                        } label: {
                            HStack {
                                Text(language.flagEmoji)
                                Text(language.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if rightLanguage.code == language.code {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VoiceConversationView()
}
#endif
