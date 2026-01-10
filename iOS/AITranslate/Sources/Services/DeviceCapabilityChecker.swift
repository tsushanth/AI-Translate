import UIKit

/// Represents the device's capability for running offline AI models
enum OfflineCapability {
    case fullSupport      // iPhone 13+, iPad Pro M1+ - Can run all Whisper models
    case standardSupport  // iPhone 11/12 - Can run Tiny/Small models
    case notSupported     // iPhone X, XS, XR, 8 and older - Online only

    var supportsOfflineMode: Bool {
        self != .notSupported
    }

    var canSkipPaywall: Bool {
        self != .notSupported
    }

    var recommendedWhisperModel: WhisperModelSize? {
        switch self {
        case .fullSupport:
            return .small
        case .standardSupport:
            return .tiny
        case .notSupported:
            return nil
        }
    }

    var supportedWhisperModels: [WhisperModelSize] {
        switch self {
        case .fullSupport:
            return [.tiny, .small, .medium]
        case .standardSupport:
            return [.tiny, .small]
        case .notSupported:
            return []
        }
    }

    var displayName: String {
        switch self {
        case .fullSupport:
            return "Full Support"
        case .standardSupport:
            return "Standard Support"
        case .notSupported:
            return "Online Only"
        }
    }

    var description: String {
        switch self {
        case .fullSupport:
            return "Your device supports all offline AI features"
        case .standardSupport:
            return "Your device supports basic offline AI features"
        case .notSupported:
            return "Your device requires an internet connection"
        }
    }
}

/// Whisper model sizes available for download
enum WhisperModelSize: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case small = "small"
    case medium = "medium"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .small: return "Small"
        case .medium: return "Medium"
        }
    }

    var downloadSize: String {
        switch self {
        case .tiny: return "~75 MB"
        case .small: return "~500 MB"
        case .medium: return "~1.5 GB"
        }
    }

    var downloadSizeBytes: Int64 {
        switch self {
        case .tiny: return 75_000_000
        case .small: return 500_000_000
        case .medium: return 1_500_000_000
        }
    }

    var accuracyDescription: String {
        switch self {
        case .tiny: return "Basic accuracy"
        case .small: return "Good accuracy"
        case .medium: return "Best accuracy"
        }
    }

    var speedDescription: String {
        switch self {
        case .tiny: return "Fastest"
        case .small: return "Balanced"
        case .medium: return "Slower"
        }
    }
}

/// Offline model package options for users
enum OfflineModelPackage: String, CaseIterable, Identifiable {
    case essential = "essential"
    case standard = "standard"
    case fullOffline = "fullOffline"
    case maximumQuality = "maximumQuality"
    case none = "none"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .essential: return "Essential"
        case .standard: return "Standard"
        case .fullOffline: return "Full Offline"
        case .maximumQuality: return "Maximum Quality"
        case .none: return "Skip for now"
        }
    }

    var subtitle: String {
        switch self {
        case .essential: return "Basic speech recognition"
        case .standard: return "Better accuracy"
        case .fullOffline: return "Multi-language translation"
        case .maximumQuality: return "Best quality + translation"
        case .none: return "Download later"
        }
    }

    var totalSize: String {
        switch self {
        case .essential: return "~75 MB"
        case .standard: return "~500 MB"
        case .fullOffline: return "~500 MB"
        case .maximumQuality: return "~1.5 GB"
        case .none: return "0 MB"
        }
    }

    var totalSizeBytes: Int64 {
        switch self {
        case .essential: return 75_000_000
        case .standard: return 500_000_000
        case .fullOffline: return 500_000_000
        case .maximumQuality: return 1_500_000_000
        case .none: return 0
        }
    }

    var whisperModel: WhisperModelSize? {
        switch self {
        case .essential: return .tiny
        case .standard: return .small
        case .fullOffline: return .small
        case .maximumQuality: return .medium
        case .none: return nil
        }
    }

    /// Whether this package includes Apple Translation for multi-language support
    var includesAppleTranslation: Bool {
        switch self {
        case .fullOffline, .maximumQuality: return true
        default: return false
        }
    }

    var features: [String] {
        switch self {
        case .essential:
            return [
                "Speech recognition in 99+ languages",
                "Translate to English only",
                "Fastest processing"
            ]
        case .standard:
            return [
                "Speech recognition in 99+ languages",
                "Translate to English only",
                "Better accuracy"
            ]
        case .fullOffline:
            return [
                "Speech recognition in 99+ languages",
                "Translate to/from: Spanish, French, German, Chinese, Japanese, Korean, and more",
                "Good accuracy"
            ]
        case .maximumQuality:
            return [
                "Speech recognition in 99+ languages",
                "Translate to/from: Spanish, French, German, Chinese, Japanese, Korean, and more",
                "Best accuracy"
            ]
        case .none:
            return [
                "Download later in Settings",
                "Requires internet"
            ]
        }
    }

    var isRecommended: Bool {
        self == .standard
    }
}

/// Apple chip generations
enum AppleChipset: Comparable {
    case a11
    case a12
    case a13
    case a14
    case a15
    case a16
    case a17
    case m1
    case m2
    case m3
    case m4
    case unknown

    var hasNeuralEngine: Bool {
        switch self {
        case .a11, .a12, .unknown:
            return false
        default:
            return true
        }
    }

    var neuralEngineTOPs: Double? {
        switch self {
        case .a11, .a12: return nil
        case .a13: return 6
        case .a14: return 11
        case .a15: return 15.8
        case .a16: return 17
        case .a17: return 35
        case .m1: return 11
        case .m2: return 15.8
        case .m3: return 18
        case .m4: return 38
        case .unknown: return nil
        }
    }
}

/// Checks device capabilities for offline AI features
final class DeviceCapabilityChecker {

    static let shared = DeviceCapabilityChecker()

    private init() {}

    /// The detected Apple chipset
    private(set) lazy var chipset: AppleChipset = detectChipset()

    /// The device's offline capability level
    private(set) lazy var offlineCapability: OfflineCapability = determineCapability()

    /// Human-readable device name
    var deviceName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return mapToDeviceName(identifier: identifier)
    }

    /// Whether the device supports offline mode
    var supportsOfflineMode: Bool {
        offlineCapability.supportsOfflineMode
    }

    /// Whether the user can skip the paywall (has free tier access)
    var canSkipPaywall: Bool {
        offlineCapability.canSkipPaywall
    }

    /// Get performance estimate for a Whisper model on this device
    func getPerformanceEstimate(for model: WhisperModelSize) -> PerformanceEstimate {
        switch (chipset, model) {
        // A17 Pro - fastest
        case (.a17, .tiny), (.a17, .small):
            return .realTime
        case (.a17, .medium):
            return .nearRealTime(multiplier: 1.2)

        // A16
        case (.a16, .tiny), (.a16, .small):
            return .realTime
        case (.a16, .medium):
            return .nearRealTime(multiplier: 1.5)

        // A15
        case (.a15, .tiny):
            return .realTime
        case (.a15, .small):
            return .nearRealTime(multiplier: 1.1)
        case (.a15, .medium):
            return .slowerThanRealTime(multiplier: 2.0)

        // A14
        case (.a14, .tiny):
            return .realTime
        case (.a14, .small):
            return .nearRealTime(multiplier: 1.3)
        case (.a14, .medium):
            return .slowerThanRealTime(multiplier: 3.0)

        // A13
        case (.a13, .tiny):
            return .nearRealTime(multiplier: 1.2)
        case (.a13, .small):
            return .slowerThanRealTime(multiplier: 2.0)
        case (.a13, .medium):
            return .notRecommended

        // M-series (all fast)
        case (.m1, _), (.m2, _), (.m3, _), (.m4, _):
            return .realTime

        default:
            return .notRecommended
        }
    }

    /// Get available model packages for this device
    func getAvailablePackages() -> [OfflineModelPackage] {
        switch offlineCapability {
        case .fullSupport:
            return [.essential, .standard, .fullOffline, .maximumQuality, .none]
        case .standardSupport:
            return [.essential, .standard, .fullOffline, .none]  // No maximum quality
        case .notSupported:
            return []
        }
    }

    /// Get the recommended package for this device
    func getRecommendedPackage() -> OfflineModelPackage? {
        switch offlineCapability {
        case .fullSupport:
            return .standard
        case .standardSupport:
            return .essential
        case .notSupported:
            return nil
        }
    }

    // MARK: - Private Methods

    private func detectChipset() -> AppleChipset {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return mapToChipset(identifier: identifier)
    }

    private func mapToChipset(identifier: String) -> AppleChipset {
        // iPhone identifiers
        if identifier.hasPrefix("iPhone") {
            let numericPart = identifier.replacingOccurrences(of: "iPhone", with: "")
            let components = numericPart.split(separator: ",")
            guard let majorVersion = components.first, let major = Int(majorVersion) else {
                return .unknown
            }

            switch major {
            case 16: return .a17  // iPhone 15 Pro
            case 15: return .a16  // iPhone 14 Pro, 15
            case 14: return .a15  // iPhone 13, 14
            case 13: return .a14  // iPhone 12
            case 12: return .a13  // iPhone 11
            case 11: return .a12  // iPhone XS, XR
            case 10: return .a11  // iPhone X, 8
            default: return .unknown
            }
        }

        // iPad identifiers
        if identifier.hasPrefix("iPad") {
            let numericPart = identifier.replacingOccurrences(of: "iPad", with: "")
            let components = numericPart.split(separator: ",")
            guard let majorVersion = components.first, let major = Int(majorVersion) else {
                return .unknown
            }

            switch major {
            case 16: return .m4  // iPad Pro M4
            case 14, 15: return .m2  // iPad Pro M2, Air M2
            case 13: return .m1  // iPad Pro M1, Air M1
            case 12: return .a14 // iPad Air 4
            case 11: return .a12 // iPad Pro 2018-2020
            default: return .a12
            }
        }

        // Simulator
        #if targetEnvironment(simulator)
        return .a15  // Assume modern for simulator
        #endif

        return .unknown
    }

    private func mapToDeviceName(identifier: String) -> String {
        // Common iPhone mappings
        let deviceNames: [String: String] = [
            // iPhone 15 series
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            // iPhone 14 series
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            // iPhone 13 series
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 Mini",
            "iPhone14,5": "iPhone 13",
            // iPhone 12 series
            "iPhone13,1": "iPhone 12 Mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            // iPhone 11 series
            "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max",
            // iPhone XS/XR
            "iPhone11,2": "iPhone XS",
            "iPhone11,4": "iPhone XS Max",
            "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            // iPhone X/8
            "iPhone10,1": "iPhone 8",
            "iPhone10,2": "iPhone 8 Plus",
            "iPhone10,3": "iPhone X",
            "iPhone10,4": "iPhone 8",
            "iPhone10,5": "iPhone 8 Plus",
            "iPhone10,6": "iPhone X",
            // iPhone SE
            "iPhone14,6": "iPhone SE (3rd gen)",
            "iPhone12,8": "iPhone SE (2nd gen)",
        ]

        if let name = deviceNames[identifier] {
            return name
        }

        #if targetEnvironment(simulator)
        return "Simulator"
        #endif

        return identifier
    }

    private func determineCapability() -> OfflineCapability {
        switch chipset {
        case .a17, .a16, .a15, .m1, .m2, .m3, .m4:
            return .fullSupport
        case .a14, .a13:
            return .standardSupport
        case .a12, .a11, .unknown:
            return .notSupported
        }
    }
}

/// Performance estimate for running a model
enum PerformanceEstimate {
    case realTime
    case nearRealTime(multiplier: Double)
    case slowerThanRealTime(multiplier: Double)
    case notRecommended

    var displayText: String {
        switch self {
        case .realTime:
            return "Real-time"
        case .nearRealTime(let multiplier):
            return "~\(String(format: "%.1fx", multiplier)) real-time"
        case .slowerThanRealTime(let multiplier):
            return "~\(String(format: "%.0fx", multiplier)) real-time"
        case .notRecommended:
            return "Not recommended"
        }
    }

    var statusIcon: String {
        switch self {
        case .realTime:
            return "checkmark.circle.fill"
        case .nearRealTime:
            return "checkmark.circle"
        case .slowerThanRealTime:
            return "exclamationmark.triangle"
        case .notRecommended:
            return "xmark.circle"
        }
    }

    var statusColor: String {
        switch self {
        case .realTime:
            return "green"
        case .nearRealTime:
            return "green"
        case .slowerThanRealTime:
            return "orange"
        case .notRecommended:
            return "red"
        }
    }

    var isRecommended: Bool {
        switch self {
        case .realTime, .nearRealTime:
            return true
        case .slowerThanRealTime, .notRecommended:
            return false
        }
    }

    /// Estimate processing time for given audio duration
    func estimatedProcessingTime(forAudioDuration seconds: Double) -> Double {
        switch self {
        case .realTime:
            return seconds
        case .nearRealTime(let multiplier):
            return seconds * multiplier
        case .slowerThanRealTime(let multiplier):
            return seconds * multiplier
        case .notRecommended:
            return seconds * 5 // Rough estimate
        }
    }
}
