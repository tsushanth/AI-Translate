import SwiftUI

/// Voice conversation translation view
@MainActor
struct VoiceConversationView: View {
    @StateObject private var viewModel = VoiceConversationViewModel()
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var showLanguageSettings = false
    @State private var showPaywall = false
    @AppStorage("hidePremiumVoiceBanner") private var hidePremiumVoiceBanner = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Offline mode banner (shown when offline)
                if !viewModel.isOnline {
                    offlineModeBanner
                }
                // Premium voice banner (shown when online and not premium)
                else if !purchaseManager.isPremium && !hidePremiumVoiceBanner {
                    premiumVoiceBanner
                }

                // Conversation messages
                conversationList

                // Bottom controls
                bottomControls
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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
        HStack(spacing: 16) {
            // App branding
            HStack(spacing: 8) {
                Text("SayIt AI")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if !viewModel.isOnline {
                    // Offline badge takes priority
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                        Text("OFFLINE")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                    )
                } else if purchaseManager.isPremium {
                    Text("PRO")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                        )
                } else if purchaseManager.isTrialActive {
                    Text("TRIAL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.yellow)
                        )
                }
            }

            Spacer()

            // Status indicator (centered)
            if viewModel.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isRecording)
                    Text("Listening")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
            } else if viewModel.isSpeaking {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text("Speaking")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.cyan)
                }
            }

            Spacer()

            // Settings button
            Button {
                showLanguageSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Premium Voice Banner

    private var premiumVoiceBanner: some View {
        let isTrialActive = purchaseManager.isTrialActive
        let daysRemaining = purchaseManager.trialDaysRemaining

        return Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isTrialActive ? "sparkles" : "waveform.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isTrialActive ? .yellow : .cyan)

                VStack(alignment: .leading, spacing: 2) {
                    if isTrialActive {
                        Text("Free Trial: \(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)

                        Text("Enjoying premium AI voices")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text("Upgrade for Natural AI Voices")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)

                        Text("Get human-like speech with Pro")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                if isTrialActive {
                    Text("Subscribe")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Dismiss button
                Button {
                    withAnimation {
                        hidePremiumVoiceBanner = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: isTrialActive
                        ? [Color.yellow.opacity(0.2), Color.orange.opacity(0.2)]
                        : [Color.cyan.opacity(0.2), Color.purple.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Offline Mode Banner

    private var offlineModeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode Active")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                Text("Voice translation available with downloaded languages")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Checkmark to indicate it's working
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.2), Color.green.opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ConversationBubble(
                            message: message,
                            onSpeak: {
                                viewModel.speakMessage(message)
                            },
                            onCopy: {
                                viewModel.copyMessage(message)
                            },
                            onFavorite: {
                                viewModel.toggleFavorite(message)
                            }
                        )
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
        HStack(spacing: 0) {
            // Left language button (tap to record in this language)
            Spacer()

            LanguageRecordButton(
                language: viewModel.leftLanguage,
                isRecording: viewModel.isRecording && viewModel.currentRecordingLanguage == .left,
                isDisabled: viewModel.isRecording && viewModel.currentRecordingLanguage != .left
            ) {
                Task {
                    await viewModel.toggleRecording(for: .left)
                }
            }

            Spacer()

            // Clear/stop button (centered)
            Button {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.clearConversation()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 56, height: 56)

                    Image(systemName: "xmark")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
            }

            Spacer()

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

            Spacer()
        }
        .padding(.vertical, 24)
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
            ZStack {
                // Pulsing animation when recording
                if isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(isRecording ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
                }

                // Main circle with flag or stop icon
                Circle()
                    .fill(isRecording ? Color.red : Color.clear)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(isRecording ? Color.red : Color.white.opacity(0.3), lineWidth: 3)
                    )

                if isRecording {
                    // Stop icon (square) when recording
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                } else {
                    // Flag emoji when not recording
                    Text(language.flagEmoji)
                        .font(.system(size: 48))
                }
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

// MARK: - Conversation Bubble

struct ConversationBubble: View {
    let message: ConversationMessage
    let onSpeak: () -> Void
    let onCopy: () -> Void
    let onFavorite: () -> Void

    @State private var isFavorite: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Original text
            Text(message.originalText)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.white)

            // Translation
            Text(message.translatedText)
                .font(.title3)
                .foregroundStyle(.cyan)

            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            // Action buttons row
            HStack(spacing: 24) {
                // Favorite button
                Button {
                    isFavorite.toggle()
                    onFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(isFavorite ? .red : .gray)
                }

                // Copy button
                Button {
                    onCopy()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }

                Spacer()

                // Speaker button
                Button {
                    onSpeak()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

// MARK: - Voice Language Settings

struct VoiceLanguageSettingsView: View {
    @Binding var leftLanguage: Language
    @Binding var rightLanguage: Language
    @Environment(\.dismiss) private var dismiss

    @State private var selectingLanguageFor: ConversationSide?
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Left Speaker") {
                    Button {
                        selectingLanguageFor = .left
                    } label: {
                        HStack {
                            Text(leftLanguage.flagEmoji)
                            Text(leftLanguage.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Right Speaker") {
                    Button {
                        selectingLanguageFor = .right
                    } label: {
                        HStack {
                            Text(rightLanguage.flagEmoji)
                            Text(rightLanguage.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $selectingLanguageFor) { side in
                LanguageSelectionListView(
                    selectedLanguage: side == .left ? $leftLanguage : $rightLanguage,
                    title: side == .left ? "Left Speaker" : "Right Speaker"
                )
            }
        }
    }
}

// MARK: - Language Selection List

struct LanguageSelectionListView: View {
    @Binding var selectedLanguage: Language
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.targetLanguages
        }
        let query = searchText.lowercased()
        return Language.targetLanguages.filter { language in
            language.name.lowercased().contains(query) ||
            language.nativeName.lowercased().contains(query) ||
            language.code.lowercased().contains(query)
        }
    }

    var body: some View {
        List {
            ForEach(filteredLanguages, id: \.code) { language in
                Button {
                    selectedLanguage = language
                    dismiss()
                } label: {
                    HStack {
                        Text(language.flagEmoji)
                        Text(language.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedLanguage.code == language.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search languages")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VoiceConversationView()
}
#endif
