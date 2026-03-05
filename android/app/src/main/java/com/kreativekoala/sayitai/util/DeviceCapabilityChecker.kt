package com.kreativekoala.sayitai.util

import android.content.Context
import android.os.Build
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Represents the device's capability for running offline AI models
 */
enum class OfflineCapability {
    /** Modern flagship devices - can run all Whisper models */
    FULL_SUPPORT,
    /** Mid-range devices - can run Tiny/Small models */
    STANDARD_SUPPORT,
    /** Older/low-end devices - Online only */
    NOT_SUPPORTED;

    val supportsOfflineMode: Boolean
        get() = this != NOT_SUPPORTED

    val canSkipPaywall: Boolean
        get() = this != NOT_SUPPORTED

    val displayName: String
        get() = when (this) {
            FULL_SUPPORT -> "Full Support"
            STANDARD_SUPPORT -> "Standard Support"
            NOT_SUPPORTED -> "Online Only"
        }

    val description: String
        get() = when (this) {
            FULL_SUPPORT -> "Your device supports all offline AI features"
            STANDARD_SUPPORT -> "Your device supports basic offline AI features"
            NOT_SUPPORTED -> "Your device requires an internet connection"
        }

    val recommendedWhisperModel: WhisperModelSize?
        get() = when (this) {
            FULL_SUPPORT -> WhisperModelSize.SMALL
            STANDARD_SUPPORT -> WhisperModelSize.TINY
            NOT_SUPPORTED -> null
        }

    val supportedWhisperModels: List<WhisperModelSize>
        get() = when (this) {
            FULL_SUPPORT -> listOf(WhisperModelSize.TINY, WhisperModelSize.SMALL, WhisperModelSize.MEDIUM)
            STANDARD_SUPPORT -> listOf(WhisperModelSize.TINY, WhisperModelSize.SMALL)
            NOT_SUPPORTED -> emptyList()
        }
}

/**
 * Whisper model sizes available for download
 */
enum class WhisperModelSize(val id: String) {
    TINY("tiny"),
    SMALL("small"),
    MEDIUM("medium");

    val displayName: String
        get() = when (this) {
            TINY -> "Tiny"
            SMALL -> "Small"
            MEDIUM -> "Medium"
        }

    val downloadSize: String
        get() = when (this) {
            TINY -> "~75 MB"
            SMALL -> "~500 MB"
            MEDIUM -> "~1.5 GB"
        }

    val downloadSizeBytes: Long
        get() = when (this) {
            TINY -> 75_000_000L
            SMALL -> 500_000_000L
            MEDIUM -> 1_500_000_000L
        }

    val accuracyDescription: String
        get() = when (this) {
            TINY -> "Basic accuracy"
            SMALL -> "Good accuracy"
            MEDIUM -> "Best accuracy"
        }
}

/**
 * Offline model package options for users
 */
enum class OfflineModelPackage(val id: String) {
    ESSENTIAL("essential"),
    STANDARD("standard"),
    FULL_OFFLINE("fullOffline"),
    MAXIMUM_QUALITY("maximumQuality"),
    NONE("none");

    val displayName: String
        get() = when (this) {
            ESSENTIAL -> "Essential"
            STANDARD -> "Standard"
            FULL_OFFLINE -> "Full Offline"
            MAXIMUM_QUALITY -> "Maximum Quality"
            NONE -> "Skip for now"
        }

    val totalSize: String
        get() = when (this) {
            ESSENTIAL -> "~75 MB"
            STANDARD -> "~500 MB"
            FULL_OFFLINE -> "~1.1 GB"
            MAXIMUM_QUALITY -> "~2.1 GB"
            NONE -> "0 MB"
        }

    val totalSizeBytes: Long
        get() = when (this) {
            ESSENTIAL -> 75_000_000L
            STANDARD -> 500_000_000L
            FULL_OFFLINE -> 1_100_000_000L
            MAXIMUM_QUALITY -> 2_100_000_000L
            NONE -> 0L
        }

    val whisperModel: WhisperModelSize?
        get() = when (this) {
            ESSENTIAL -> WhisperModelSize.TINY
            STANDARD -> WhisperModelSize.SMALL
            FULL_OFFLINE -> WhisperModelSize.SMALL
            MAXIMUM_QUALITY -> WhisperModelSize.MEDIUM
            NONE -> null
        }

    val includesNLLB: Boolean
        get() = when (this) {
            FULL_OFFLINE, MAXIMUM_QUALITY -> true
            else -> false
        }

    val features: List<String>
        get() = when (this) {
            ESSENTIAL -> listOf(
                "Speech to text in any language",
                "Translate speech to English",
                "Basic device TTS"
            )
            STANDARD -> listOf(
                "Better speech recognition accuracy",
                "Translate speech to English",
                "Basic device TTS"
            )
            FULL_OFFLINE -> listOf(
                "Good speech recognition accuracy",
                "Translate between ALL 30 languages",
                "Full offline translation",
                "Basic device TTS"
            )
            MAXIMUM_QUALITY -> listOf(
                "Best speech recognition accuracy",
                "Translate between ALL 30 languages",
                "Full offline translation",
                "Basic device TTS"
            )
            NONE -> listOf(
                "Download later in Settings",
                "Requires internet to use app"
            )
        }
}

/**
 * Performance estimate for running a model
 */
sealed class PerformanceEstimate {
    object RealTime : PerformanceEstimate()
    data class NearRealTime(val multiplier: Double) : PerformanceEstimate()
    data class SlowerThanRealTime(val multiplier: Double) : PerformanceEstimate()
    object NotRecommended : PerformanceEstimate()

    val displayText: String
        get() = when (this) {
            is RealTime -> "Real-time"
            is NearRealTime -> "~${String.format("%.1f", multiplier)}x real-time"
            is SlowerThanRealTime -> "~${String.format("%.0f", multiplier)}x real-time"
            is NotRecommended -> "Not recommended"
        }

    val statusColor: String
        get() = when (this) {
            is RealTime, is NearRealTime -> "green"
            is SlowerThanRealTime -> "orange"
            is NotRecommended -> "red"
        }

    val isRecommended: Boolean
        get() = when (this) {
            is RealTime, is NearRealTime -> true
            else -> false
        }
}

/**
 * Checks device capabilities for offline AI features
 */
@Singleton
class DeviceCapabilityChecker @Inject constructor(
    @ApplicationContext private val context: Context
) {
    /**
     * The device's offline capability level
     */
    val offlineCapability: OfflineCapability by lazy { determineCapability() }

    /**
     * Human-readable device name
     */
    val deviceName: String
        get() = "${Build.MANUFACTURER} ${Build.MODEL}"

    /**
     * Whether the device supports offline mode
     */
    val supportsOfflineMode: Boolean
        get() = offlineCapability.supportsOfflineMode

    /**
     * Whether the user can skip the paywall (has free tier access)
     */
    val canSkipPaywall: Boolean
        get() = offlineCapability.canSkipPaywall

    /**
     * Get performance estimate for a Whisper model on this device
     */
    fun getPerformanceEstimate(model: WhisperModelSize): PerformanceEstimate {
        val deviceTier = getDeviceTier()

        return when {
            // High-end devices (Snapdragon 8 Gen series, Tensor, etc.)
            deviceTier == DeviceTier.HIGH_END -> when (model) {
                WhisperModelSize.TINY, WhisperModelSize.SMALL -> PerformanceEstimate.RealTime
                WhisperModelSize.MEDIUM -> PerformanceEstimate.NearRealTime(1.2)
            }
            // Mid-range devices
            deviceTier == DeviceTier.MID_RANGE -> when (model) {
                WhisperModelSize.TINY -> PerformanceEstimate.RealTime
                WhisperModelSize.SMALL -> PerformanceEstimate.NearRealTime(1.3)
                WhisperModelSize.MEDIUM -> PerformanceEstimate.SlowerThanRealTime(2.5)
            }
            // Entry-level devices
            deviceTier == DeviceTier.ENTRY_LEVEL -> when (model) {
                WhisperModelSize.TINY -> PerformanceEstimate.NearRealTime(1.5)
                WhisperModelSize.SMALL -> PerformanceEstimate.SlowerThanRealTime(2.5)
                WhisperModelSize.MEDIUM -> PerformanceEstimate.NotRecommended
            }
            // Legacy devices
            else -> PerformanceEstimate.NotRecommended
        }
    }

    /**
     * Get available model packages for this device
     */
    fun getAvailablePackages(): List<OfflineModelPackage> {
        return when (offlineCapability) {
            OfflineCapability.FULL_SUPPORT -> listOf(
                OfflineModelPackage.ESSENTIAL,
                OfflineModelPackage.STANDARD,
                OfflineModelPackage.FULL_OFFLINE,
                OfflineModelPackage.MAXIMUM_QUALITY,
                OfflineModelPackage.NONE
            )
            OfflineCapability.STANDARD_SUPPORT -> listOf(
                OfflineModelPackage.ESSENTIAL,
                OfflineModelPackage.STANDARD,
                OfflineModelPackage.FULL_OFFLINE,
                OfflineModelPackage.NONE
            )
            OfflineCapability.NOT_SUPPORTED -> emptyList()
        }
    }

    /**
     * Get the recommended package for this device
     */
    fun getRecommendedPackage(): OfflineModelPackage? {
        return when (offlineCapability) {
            OfflineCapability.FULL_SUPPORT -> OfflineModelPackage.STANDARD
            OfflineCapability.STANDARD_SUPPORT -> OfflineModelPackage.ESSENTIAL
            OfflineCapability.NOT_SUPPORTED -> null
        }
    }

    // MARK: - Private Methods

    private enum class DeviceTier {
        HIGH_END,
        MID_RANGE,
        ENTRY_LEVEL,
        LEGACY
    }

    private fun getDeviceTier(): DeviceTier {
        // Use available RAM and SDK version as heuristics
        val runtime = Runtime.getRuntime()
        val maxMemoryMB = runtime.maxMemory() / (1024 * 1024)
        val sdkVersion = Build.VERSION.SDK_INT

        return when {
            // High-end: 8GB+ RAM and Android 12+
            maxMemoryMB >= 6000 && sdkVersion >= Build.VERSION_CODES.S -> DeviceTier.HIGH_END
            // Mid-range: 4GB+ RAM and Android 10+
            maxMemoryMB >= 3000 && sdkVersion >= Build.VERSION_CODES.Q -> DeviceTier.MID_RANGE
            // Entry-level: 2GB+ RAM and Android 8+
            maxMemoryMB >= 1500 && sdkVersion >= Build.VERSION_CODES.O -> DeviceTier.ENTRY_LEVEL
            // Legacy
            else -> DeviceTier.LEGACY
        }
    }

    private fun determineCapability(): OfflineCapability {
        val deviceTier = getDeviceTier()
        val sdkVersion = Build.VERSION.SDK_INT

        // Android 8 (API 26) minimum for NNAPI support
        if (sdkVersion < Build.VERSION_CODES.O) {
            return OfflineCapability.NOT_SUPPORTED
        }

        return when (deviceTier) {
            DeviceTier.HIGH_END -> OfflineCapability.FULL_SUPPORT
            DeviceTier.MID_RANGE -> OfflineCapability.STANDARD_SUPPORT
            DeviceTier.ENTRY_LEVEL -> OfflineCapability.STANDARD_SUPPORT
            DeviceTier.LEGACY -> OfflineCapability.NOT_SUPPORTED
        }
    }
}
