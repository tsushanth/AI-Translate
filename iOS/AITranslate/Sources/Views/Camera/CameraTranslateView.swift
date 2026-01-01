import SwiftUI
import AVFoundation
import Vision

/// Camera-based OCR translation view
@MainActor
struct CameraTranslateView: View {
    @StateObject private var viewModel = CameraTranslateViewModel()
    @State private var showLanguageSettings = false

    // Highlight box state
    @State private var highlightFrame: CGRect = .zero
    @State private var isDragging = false
    @State private var isResizing = false
    @State private var dragOffset: CGSize = .zero
    @State private var needsInitialTranslation = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview or captured image
                if let capturedImage = viewModel.capturedImage {
                    // Show captured image
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                } else {
                    // Live camera preview
                    CameraPreviewView(session: viewModel.captureSession)
                        .ignoresSafeArea()
                }

                // Overlay UI
                VStack {
                    // Top bar
                    topBar

                    Spacer()

                    // Mode selector and prompt (only when not captured)
                    if !viewModel.hasCapture {
                        VStack(spacing: 16) {
                            Text("Scan some Text")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))

                            modeSelector
                        }
                        .padding(.bottom, 20)
                    }

                    // Bottom controls
                    bottomControls
                }

                // Highlight box with translation (show after capture)
                if viewModel.hasCapture {
                    highlightBoxOverlay(translation: viewModel.translatedText, in: geometry)
                }

                // Loading overlay
                if viewModel.isProcessing || viewModel.isTranslatingRegion {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text(viewModel.isTranslatingRegion ? "Scanning region..." : "Translating...")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                    }
                }
            }
            .onAppear {
                viewModel.startSession()
                // Initialize highlight box in center
                initializeHighlightBox(in: geometry)
            }
            .onDisappear {
                viewModel.stopSession()
            }
        }
        .onChange(of: viewModel.hasCapture) { oldValue, newValue in
            if newValue && !oldValue {
                // Just captured - flag that we need to reinitialize and translate
                needsInitialTranslation = true
            }
        }
        .sheet(isPresented: $showLanguageSettings) {
            CameraLanguageSettingsView(
                sourceLanguage: $viewModel.sourceLanguage,
                targetLanguage: $viewModel.targetLanguage
            )
        }
        .fullScreenCover(isPresented: $viewModel.showFullscreen) {
            if let translation = viewModel.translatedText {
                CameraFullscreenView(
                    translation: translation,
                    targetLanguage: viewModel.targetLanguage,
                    onSpeak: { viewModel.speakTranslation() },
                    isSpeaking: viewModel.isSpeaking
                )
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Camera Access Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings to use the camera translation feature.")
        }
    }

    // MARK: - Initialize Highlight Box

    private func initializeHighlightBox(in geometry: GeometryProxy) {
        // Default highlight box - covers a reasonable portion of center screen
        let boxWidth: CGFloat = geometry.size.width * 0.85
        let boxHeight: CGFloat = 100
        let centerX = (geometry.size.width - boxWidth) / 2
        let centerY = (geometry.size.height - boxHeight) / 2 - 50 // Slightly above center
        highlightFrame = CGRect(x: centerX, y: centerY, width: boxWidth, height: boxHeight)
    }

    /// Reinitialize highlight box when capture happens - pick a smart region
    private func initializeHighlightBoxForCapture(in geometry: GeometryProxy) {
        // Pick a region that's likely to contain text
        // Start with a reasonably sized box in the upper-middle area (where text often is)
        let boxWidth: CGFloat = geometry.size.width * 0.85
        let boxHeight: CGFloat = min(120, geometry.size.height * 0.15)

        // Position in upper-third of screen where text commonly appears
        let centerX = (geometry.size.width - boxWidth) / 2
        let centerY = geometry.size.height * 0.35 - (boxHeight / 2)

        highlightFrame = CGRect(
            x: max(8, centerX),
            y: max(80, centerY), // Keep below top bar
            width: boxWidth,
            height: boxHeight
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Flash toggle
            Button {
                viewModel.toggleFlash()
            } label: {
                Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .opacity(viewModel.hasCapture ? 0.3 : 1)
            .disabled(viewModel.hasCapture)

            Spacer()

            // Close button (when showing capture)
            if viewModel.hasCapture {
                Button {
                    viewModel.clearCapture()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.scanMode = .text
            } label: {
                Text("Text")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(viewModel.scanMode == .text ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(viewModel.scanMode == .text ? Color.gray.opacity(0.6) : Color.clear)
                    )
            }

            Button {
                viewModel.scanMode = .object
            } label: {
                Text("Object")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(viewModel.scanMode == .object ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(viewModel.scanMode == .object ? Color.gray.opacity(0.6) : Color.clear)
                    )
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
        )
    }

    // MARK: - Highlight Box Overlay

    private func highlightBoxOverlay(translation: String?, in geometry: GeometryProxy) -> some View {
        ZStack {
            // Semi-transparent overlay outside the highlight box
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .frame(width: highlightFrame.width, height: highlightFrame.height)
                                .position(x: highlightFrame.midX, y: highlightFrame.midY)
                                .blendMode(.destinationOut)
                        )
                )

            // Highlight box border
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .frame(width: highlightFrame.width, height: highlightFrame.height)
                .position(x: highlightFrame.midX, y: highlightFrame.midY)

            // Action buttons above the highlight box
            actionButtonsBar
                .position(x: highlightFrame.midX, y: highlightFrame.minY - 30)

            // Draggable highlight content area
            ZStack {
                // Background for drag detection
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.001)) // Nearly invisible but captures touches

                // Translation overlay inside the highlight box (only if we have translation)
                if let translation = translation, !translation.isEmpty {
                    translationBox(translation: translation)
                } else if viewModel.isTranslatingRegion {
                    // Show loading indicator inside highlight box
                    ProgressView()
                        .tint(.white)
                } else {
                    // Show "Drag to translate" hint
                    Text("Drag to select area")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: highlightFrame.width - 8, height: highlightFrame.height - 8)
            .position(x: highlightFrame.midX, y: highlightFrame.midY)
            .contentShape(Rectangle())
            .gesture(dragGesture(in: geometry))

            // Resize handles at corners
            resizeHandles(in: geometry)
        }
        .onChange(of: needsInitialTranslation) { oldValue, newValue in
            if newValue {
                // Reinitialize highlight box for captured image
                initializeHighlightBoxForCapture(in: geometry)
                needsInitialTranslation = false
                // Trigger initial region translation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    translateHighlightedRegion(in: geometry)
                }
            }
        }
    }

    // MARK: - Action Buttons Bar

    private var actionButtonsBar: some View {
        HStack(spacing: 12) {
            // Speaker button
            Button {
                viewModel.speakTranslation()
            } label: {
                Image(systemName: viewModel.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.7)))
            }

            // Share button
            ShareLink(item: viewModel.shareTranslation()) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.7)))
            }

            // Expand/Fullscreen button
            Button {
                viewModel.showFullscreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.7)))
            }

            // Cancel/Close button
            Button {
                viewModel.clearCapture()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.7)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }

    // MARK: - Translation Box

    private func translationBox(translation: String) -> some View {
        Text(translation)
            .font(.system(size: calculateFontSize(for: translation)))
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.3)
            .padding(8)
            .frame(
                maxWidth: highlightFrame.width - 24,
                maxHeight: highlightFrame.height - 24
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.85))
            )
    }

    /// Calculate appropriate font size based on text length and highlight box size
    private func calculateFontSize(for text: String) -> CGFloat {
        let area = highlightFrame.width * highlightFrame.height
        let textLength = text.count

        // Base font size calculation
        let baseFontSize: CGFloat = 16

        // Adjust based on area and text length
        let areaFactor = sqrt(area) / 200
        let lengthFactor = max(0.5, 1.0 - (Double(textLength) / 200.0))

        let calculatedSize = baseFontSize * areaFactor * lengthFactor

        // Clamp between reasonable bounds
        return max(10, min(24, calculatedSize))
    }

    // MARK: - Drag Gesture

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                let newX = highlightFrame.origin.x + value.translation.width - dragOffset.width
                let newY = highlightFrame.origin.y + value.translation.height - dragOffset.height

                // Clamp to screen bounds
                let clampedX = max(0, min(newX, geometry.size.width - highlightFrame.width))
                let clampedY = max(60, min(newY, geometry.size.height - highlightFrame.height - 120))

                highlightFrame.origin.x = clampedX
                highlightFrame.origin.y = clampedY
                dragOffset = value.translation
            }
            .onEnded { _ in
                isDragging = false
                dragOffset = .zero
                // Trigger region translation when drag ends
                translateHighlightedRegion(in: geometry)
            }
    }

    // MARK: - Translate Highlighted Region

    private func translateHighlightedRegion(in geometry: GeometryProxy) {
        // Convert highlight frame to normalized coordinates (0-1)
        // Account for the scaledToFill behavior of the image
        guard let image = viewModel.capturedImage else { return }

        let imageAspect = image.size.width / image.size.height
        let viewAspect = geometry.size.width / geometry.size.height

        var imageRect: CGRect

        if imageAspect > viewAspect {
            // Image is wider - height fills view, width is cropped
            let scaledWidth = geometry.size.height * imageAspect
            let xOffset = (scaledWidth - geometry.size.width) / 2
            imageRect = CGRect(
                x: -xOffset,
                y: 0,
                width: scaledWidth,
                height: geometry.size.height
            )
        } else {
            // Image is taller - width fills view, height is cropped
            let scaledHeight = geometry.size.width / imageAspect
            let yOffset = (scaledHeight - geometry.size.height) / 2
            imageRect = CGRect(
                x: 0,
                y: -yOffset,
                width: geometry.size.width,
                height: scaledHeight
            )
        }

        // Convert highlight frame to normalized image coordinates
        let normalizedX = (highlightFrame.origin.x - imageRect.origin.x) / imageRect.width
        let normalizedY = (highlightFrame.origin.y - imageRect.origin.y) / imageRect.height
        let normalizedWidth = highlightFrame.width / imageRect.width
        let normalizedHeight = highlightFrame.height / imageRect.height

        let normalizedRect = CGRect(
            x: max(0, min(1, normalizedX)),
            y: max(0, min(1, normalizedY)),
            width: max(0, min(1 - normalizedX, normalizedWidth)),
            height: max(0, min(1 - normalizedY, normalizedHeight))
        )

        viewModel.translateRegion(normalizedRect: normalizedRect, viewSize: geometry.size)
    }

    // MARK: - Resize Handles

    private func resizeHandles(in geometry: GeometryProxy) -> some View {
        Group {
            // Bottom-right corner resize handle
            Circle()
                .fill(Color.cyan)
                .frame(width: 20, height: 20)
                .position(x: highlightFrame.maxX, y: highlightFrame.maxY)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isResizing = true
                            let newWidth = max(100, highlightFrame.width + value.translation.width - dragOffset.width)
                            let newHeight = max(60, highlightFrame.height + value.translation.height - dragOffset.height)

                            // Clamp to screen bounds
                            let maxWidth = geometry.size.width - highlightFrame.origin.x
                            let maxHeight = geometry.size.height - highlightFrame.origin.y - 120

                            highlightFrame.size.width = min(newWidth, maxWidth)
                            highlightFrame.size.height = min(newHeight, maxHeight)
                            dragOffset = value.translation
                        }
                        .onEnded { _ in
                            isResizing = false
                            dragOffset = .zero
                            // Trigger region translation when resize ends
                            translateHighlightedRegion(in: geometry)
                        }
                )
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 40) {
            // Source language flag
            LanguageFlagButton(language: viewModel.sourceLanguage) {
                showLanguageSettings = true
            }
            .opacity(viewModel.hasCapture ? 0.5 : 1)
            .disabled(viewModel.hasCapture)

            // Capture button (only when not captured)
            if !viewModel.hasCapture {
                Button {
                    viewModel.captureAndTranslate()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 58, height: 58)
                    }
                }
            } else {
                // Placeholder to maintain layout
                Spacer()
                    .frame(width: 70, height: 70)
            }

            // Target language flag
            LanguageFlagButton(language: viewModel.targetLanguage) {
                showLanguageSettings = true
            }
            .opacity(viewModel.hasCapture ? 0.5 : 1)
            .disabled(viewModel.hasCapture)
        }
        .padding(.bottom, 30)
    }
}

// MARK: - Language Flag Button

struct LanguageFlagButton: View {
    let language: Language
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(language.flagEmoji)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                )
        }
    }
}

// MARK: - Camera Language Settings

struct CameraLanguageSettingsView: View {
    @Binding var sourceLanguage: Language
    @Binding var targetLanguage: Language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Source Language") {
                    ForEach(Language.targetLanguages, id: \.code) { language in
                        Button {
                            sourceLanguage = language
                        } label: {
                            HStack {
                                Text(language.flagEmoji)
                                Text(language.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if sourceLanguage.code == language.code {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                Section("Target Language") {
                    ForEach(Language.targetLanguages, id: \.code) { language in
                        Button {
                            targetLanguage = language
                        } label: {
                            HStack {
                                Text(language.flagEmoji)
                                Text(language.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if targetLanguage.code == language.code {
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

// MARK: - Camera Fullscreen View

struct CameraFullscreenView: View {
    let translation: String
    let targetLanguage: Language
    let onSpeak: () -> Void
    let isSpeaking: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding()

                Spacer()

                // Translation display
                VStack(spacing: 16) {
                    Text(targetLanguage.displayName)
                        .font(.caption)
                        .foregroundStyle(.gray)

                    Text(translation)
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Speak button
                Button {
                    onSpeak()
                } label: {
                    Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Color.blue))
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            previewLayer.session = session
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.videoGravity = .resizeAspectFill
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    CameraTranslateView()
}
#endif
