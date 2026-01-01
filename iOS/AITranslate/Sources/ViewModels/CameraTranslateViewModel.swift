import Foundation
import SwiftUI
import AVFoundation
import Vision

/// Scan mode for camera translation
enum CameraScanMode {
    case text
    case object
}

/// ViewModel for camera-based OCR translation
@MainActor
final class CameraTranslateViewModel: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var scanMode: CameraScanMode = .text
    @Published var sourceLanguage: Language = Language.find(byCode: "en") ?? Language.supportedLanguages[0]
    @Published var targetLanguage: Language = Language.find(byCode: "es") ?? Language.supportedLanguages[1]

    @Published private(set) var recognizedText: String?
    @Published private(set) var translatedText: String?
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var isFlashOn: Bool = false
    @Published private(set) var hasCapture: Bool = false
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var isTranslatingRegion: Bool = false

    @Published var showError: Bool = false
    @Published var errorMessage: String?
    @Published var showPermissionAlert: Bool = false
    @Published var showFullscreen: Bool = false

    // MARK: - Camera Properties

    let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDevice: AVCaptureDevice?

    // MARK: - Services

    private let translationService: TranslationService
    private let textToSpeechService: TextToSpeechService

    // MARK: - Initialization

    override init() {
        self.translationService = RemoteTranslationService()
        self.textToSpeechService = TextToSpeechService()
        super.init()
        textToSpeechService.delegate = self
    }

    // MARK: - Camera Setup

    func startSession() {
        Task {
            await setupCamera()
        }
    }

    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func setupCamera() async {
        // Check permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await configureSession()
            } else {
                showPermissionAlert = true
            }
        case .authorized:
            await configureSession()
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            showPermissionAlert = true
        }
    }

    private func configureSession() async {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // Add video input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            handleError("Camera not available")
            captureSession.commitConfiguration()
            return
        }

        videoDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            handleError("Failed to configure camera: \(error.localizedDescription)")
            captureSession.commitConfiguration()
            return
        }

        // Add photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()

        // Start session on background thread
        Task.detached { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    // MARK: - Flash Control

    func toggleFlash() {
        guard let device = videoDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = isFlashOn ? .off : .on
            isFlashOn.toggle()
            device.unlockForConfiguration()
        } catch {
            handleError("Failed to toggle flash")
        }
    }

    // MARK: - Capture and Translate

    func captureAndTranslate() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        isProcessing = true
    }

    private func processImage(_ image: CGImage) async {
        // Perform OCR
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])

        let request = VNRecognizeTextRequest { [weak self] request, error in
            Task { @MainActor in
                await self?.handleOCRResult(request: request, error: error)
            }
        }

        // Configure recognition
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [sourceLanguage.code, "en"]
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])
        } catch {
            handleError("OCR failed: \(error.localizedDescription)")
            isProcessing = false
        }
    }

    private func handleOCRResult(request: VNRequest, error: Error?) async {
        if let error = error {
            handleError("Text recognition failed: \(error.localizedDescription)")
            isProcessing = false
            return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            handleError("No text found in image")
            isProcessing = false
            return
        }

        // Extract text from observations
        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        let fullText = recognizedStrings.joined(separator: " ")

        guard !fullText.isEmpty else {
            handleError("No text detected in the image")
            isProcessing = false
            return
        }

        recognizedText = fullText
        hasCapture = true

        // Translate the recognized text
        await translateText(fullText)
    }

    private func translateText(_ text: String) async {
        do {
            let result = try await translationService.translate(
                text: text,
                from: sourceLanguage.code,
                to: targetLanguage.code
            )

            translatedText = result.translatedText
            isProcessing = false

        } catch {
            handleError("Translation failed: \(error.localizedDescription)")
            isProcessing = false
        }
    }

    // MARK: - Actions

    func speakTranslation() {
        guard let text = translatedText else { return }
        textToSpeechService.speak(text: text, languageCode: targetLanguage.speechLocaleCode)
    }

    func copyTranslation() {
        guard let text = translatedText else { return }
        UIPasteboard.general.string = text
    }

    func clearCapture() {
        recognizedText = nil
        translatedText = nil
        hasCapture = false
        capturedImage = nil
    }

    func shareTranslation() -> String {
        guard let original = recognizedText, let translation = translatedText else { return "" }
        return "\(original)\n\n\(translation)"
    }

    /// Translate a specific region of the captured image
    /// - Parameters:
    ///   - normalizedRect: The region to translate, normalized to 0-1 coordinates (origin at top-left)
    ///   - viewSize: The size of the view displaying the image
    func translateRegion(normalizedRect: CGRect, viewSize: CGSize) {
        guard let image = capturedImage, let cgImage = image.cgImage else { return }

        isTranslatingRegion = true

        // Convert normalized rect to image coordinates
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Calculate the crop rect in image coordinates
        let cropRect = CGRect(
            x: normalizedRect.origin.x * imageWidth,
            y: normalizedRect.origin.y * imageHeight,
            width: normalizedRect.width * imageWidth,
            height: normalizedRect.height * imageHeight
        )

        // Ensure crop rect is within bounds
        let clampedRect = cropRect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        guard clampedRect.width > 0 && clampedRect.height > 0 else {
            isTranslatingRegion = false
            return
        }

        // Crop the image to the selected region
        guard let croppedCGImage = cgImage.cropping(to: clampedRect) else {
            isTranslatingRegion = false
            handleError("Failed to crop image region")
            return
        }

        Task {
            await processImage(croppedCGImage)
            isTranslatingRegion = false
        }
    }

    // MARK: - Error Handling

    private func handleError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraTranslateViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            if let error = error {
                handleError("Photo capture failed: \(error.localizedDescription)")
                isProcessing = false
                return
            }

            guard let imageData = photo.fileDataRepresentation(),
                  let uiImage = UIImage(data: imageData),
                  let cgImage = uiImage.cgImage else {
                handleError("Failed to process captured image")
                isProcessing = false
                return
            }

            capturedImage = uiImage
            hasCapture = true
            isProcessing = false
            // Don't process full image - wait for region selection in the view
        }
    }
}

// MARK: - TextToSpeechDelegate

extension CameraTranslateViewModel: TextToSpeechDelegate {
    nonisolated func textToSpeechDidStart() {
        Task { @MainActor in
            isSpeaking = true
        }
    }

    nonisolated func textToSpeechDidFinish() {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    nonisolated func textToSpeechDidCancel() {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    nonisolated func textToSpeech(didFailWithError error: TextToSpeechError) {
        Task { @MainActor in
            isSpeaking = false
            handleError(error.localizedDescription)
        }
    }
}
