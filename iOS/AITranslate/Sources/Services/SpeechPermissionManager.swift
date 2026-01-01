import Foundation
import Speech
import AVFoundation
import UIKit

/// Centralized manager for speech-related permissions
@MainActor
final class SpeechPermissionManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var microphoneStatus: MicrophonePermissionStatus = .notDetermined
    @Published private(set) var speechRecognitionStatus: SpeechPermissionStatus = .notDetermined

    /// Combined status for speech recognition (requires both permissions)
    var canRecordSpeech: Bool {
        microphoneStatus == .authorized && speechRecognitionStatus == .authorized
    }

    // MARK: - Singleton

    static let shared = SpeechPermissionManager()

    private init() {
        refreshStatus()
    }

    // MARK: - Status Types

    enum MicrophonePermissionStatus {
        case notDetermined
        case authorized
        case denied

        var isAuthorized: Bool { self == .authorized }
    }

    enum SpeechPermissionStatus {
        case notDetermined
        case authorized
        case denied
        case restricted

        var isAuthorized: Bool { self == .authorized }
    }

    // MARK: - Public Methods

    /// Refreshes the current permission status
    func refreshStatus() {
        // Microphone status
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            microphoneStatus = .notDetermined
        case .granted:
            microphoneStatus = .authorized
        case .denied:
            microphoneStatus = .denied
        @unknown default:
            microphoneStatus = .denied
        }

        // Speech recognition status
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            speechRecognitionStatus = .notDetermined
        case .authorized:
            speechRecognitionStatus = .authorized
        case .denied:
            speechRecognitionStatus = .denied
        case .restricted:
            speechRecognitionStatus = .restricted
        @unknown default:
            speechRecognitionStatus = .denied
        }
    }

    /// Requests microphone permission
    /// - Returns: Whether permission was granted
    func requestMicrophonePermission() async -> Bool {
        guard microphoneStatus == .notDetermined else {
            return microphoneStatus == .authorized
        }

        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        microphoneStatus = granted ? .authorized : .denied
        return granted
    }

    /// Requests speech recognition permission
    /// - Returns: Whether permission was granted
    func requestSpeechRecognitionPermission() async -> Bool {
        guard speechRecognitionStatus == .notDetermined else {
            return speechRecognitionStatus == .authorized
        }

        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch status {
        case .authorized:
            speechRecognitionStatus = .authorized
            return true
        case .denied:
            speechRecognitionStatus = .denied
        case .restricted:
            speechRecognitionStatus = .restricted
        case .notDetermined:
            speechRecognitionStatus = .notDetermined
        @unknown default:
            speechRecognitionStatus = .denied
        }

        return false
    }

    /// Requests all permissions needed for speech recognition
    /// - Returns: Whether all permissions were granted
    func requestAllSpeechPermissions() async -> Bool {
        // Request microphone first (required for speech recognition)
        let micGranted = await requestMicrophonePermission()
        guard micGranted else { return false }

        // Then request speech recognition
        let speechGranted = await requestSpeechRecognitionPermission()
        return speechGranted
    }

    /// Opens the app settings in the Settings app
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Info.plist Keys Required

/*
 Add these keys to your Info.plist:

 <key>NSMicrophoneUsageDescription</key>
 <string>We need microphone access to recognize your speech for translation.</string>

 <key>NSSpeechRecognitionUsageDescription</key>
 <string>We need speech recognition to convert your spoken words to text for translation.</string>
*/

// MARK: - Usage Example

/*
 // In your View or ViewModel:

 @StateObject private var permissionManager = SpeechPermissionManager.shared

 func startVoiceInput() async {
     // Check and request permissions
     guard await permissionManager.requestAllSpeechPermissions() else {
         // Show alert directing user to Settings
         if permissionManager.microphoneStatus == .denied {
             showMicrophonePermissionAlert()
         } else if permissionManager.speechRecognitionStatus == .denied {
             showSpeechRecognitionPermissionAlert()
         }
         return
     }

     // Start recording
     try? speechRecognitionService.startRecording(languageCode: "en-US")
 }

 func showMicrophonePermissionAlert() {
     // Show alert with button to open Settings
     // permissionManager.openAppSettings()
 }
*/
