package com.kreativekoala.sayitai.util

import android.content.Context
import android.content.SharedPreferences
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.text.DecimalFormat
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Status of a model download
 */
sealed class DownloadStatus {
    object Idle : DownloadStatus()
    data class Downloading(val progress: Double) : DownloadStatus()
    object Processing : DownloadStatus()
    object Completed : DownloadStatus()
    data class Failed(val error: String) : DownloadStatus()

    val isDownloading: Boolean
        get() = this is Downloading

    val isCompleted: Boolean
        get() = this == Completed
}

/**
 * Model type identifier
 */
enum class OfflineModelType(val id: String) {
    WHISPER_TINY("whisper-tiny"),
    WHISPER_SMALL("whisper-small"),
    WHISPER_MEDIUM("whisper-medium"),
    NLLB("nllb-200");

    val displayName: String
        get() = when (this) {
            WHISPER_TINY -> "Whisper Tiny"
            WHISPER_SMALL -> "Whisper Small"
            WHISPER_MEDIUM -> "Whisper Medium"
            NLLB -> "NLLB Translation"
        }

    val fileName: String
        get() = when (this) {
            WHISPER_TINY -> "whisper-tiny.bin"
            WHISPER_SMALL -> "whisper-small.bin"
            WHISPER_MEDIUM -> "whisper-medium.bin"
            NLLB -> "nllb-200-distilled.bin"
        }

    val downloadSizeBytes: Long
        get() = when (this) {
            WHISPER_TINY -> 75_000_000L
            WHISPER_SMALL -> 500_000_000L
            WHISPER_MEDIUM -> 1_500_000_000L
            NLLB -> 600_000_000L
        }

    val downloadSizeFormatted: String
        get() = formatBytes(downloadSizeBytes)

    /**
     * Base URL for model downloads (placeholder - replace with actual CDN)
     */
    val downloadURL: String
        get() = "https://models.sayitai.app/$id/$fileName"

    companion object {
        private fun formatBytes(bytes: Long): String {
            if (bytes < 1024) return "$bytes B"
            val kb = bytes / 1024.0
            if (kb < 1024) return "${DecimalFormat("#.#").format(kb)} KB"
            val mb = kb / 1024.0
            if (mb < 1024) return "${DecimalFormat("#.#").format(mb)} MB"
            val gb = mb / 1024.0
            return "${DecimalFormat("#.#").format(gb)} GB"
        }
    }
}

/**
 * Manages downloading, storing, and accessing offline AI models
 */
@Singleton
class OfflineModelManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val prefs: SharedPreferences = context.getSharedPreferences("offline_models", Context.MODE_PRIVATE)

    // StateFlow for observable state
    private val _downloadedWhisperModel = MutableStateFlow<WhisperModelSize?>(null)
    val downloadedWhisperModel: StateFlow<WhisperModelSize?> = _downloadedWhisperModel.asStateFlow()

    private val _isNLLBDownloaded = MutableStateFlow(false)
    val isNLLBDownloaded: StateFlow<Boolean> = _isNLLBDownloaded.asStateFlow()

    private val _downloadProgress = MutableStateFlow(0.0)
    val downloadProgress: StateFlow<Double> = _downloadProgress.asStateFlow()

    private val _downloadStatus = MutableStateFlow<DownloadStatus>(DownloadStatus.Idle)
    val downloadStatus: StateFlow<DownloadStatus> = _downloadStatus.asStateFlow()

    private val _currentlyDownloading = MutableStateFlow<OfflineModelType?>(null)
    val currentlyDownloading: StateFlow<OfflineModelType?> = _currentlyDownloading.asStateFlow()

    private val modelsDirectory: File
        get() {
            val dir = File(context.filesDir, "OfflineModels")
            if (!dir.exists()) {
                dir.mkdirs()
            }
            return dir
        }

    init {
        loadDownloadedModels()
    }

    // MARK: - Public Methods

    /**
     * Download an offline model package
     */
    suspend fun downloadPackage(modelPackage: OfflineModelPackage) {
        if (modelPackage == OfflineModelPackage.NONE) return

        val modelsToDownload = mutableListOf<OfflineModelType>()

        modelPackage.whisperModel?.let { whisperModel ->
            when (whisperModel) {
                WhisperModelSize.TINY -> modelsToDownload.add(OfflineModelType.WHISPER_TINY)
                WhisperModelSize.SMALL -> modelsToDownload.add(OfflineModelType.WHISPER_SMALL)
                WhisperModelSize.MEDIUM -> modelsToDownload.add(OfflineModelType.WHISPER_MEDIUM)
            }
        }

        if (modelPackage.includesNLLB) {
            modelsToDownload.add(OfflineModelType.NLLB)
        }

        for (model in modelsToDownload) {
            downloadModel(model)
        }

        loadDownloadedModels()
    }

    /**
     * Download a specific model
     */
    suspend fun downloadModel(modelType: OfflineModelType) {
        _currentlyDownloading.value = modelType
        _downloadStatus.value = DownloadStatus.Downloading(0.0)
        _downloadProgress.value = 0.0

        try {
            withContext(Dispatchers.IO) {
                val url = URL(modelType.downloadURL)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connect()

                if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                    throw OfflineModelException.DownloadFailed("HTTP ${connection.responseCode}")
                }

                val fileLength = connection.contentLengthLong
                val destinationFile = File(modelsDirectory, modelType.fileName)

                // Delete existing file if present
                if (destinationFile.exists()) {
                    destinationFile.delete()
                }

                connection.inputStream.use { input ->
                    FileOutputStream(destinationFile).use { output ->
                        val buffer = ByteArray(8192)
                        var totalBytesRead = 0L
                        var bytesRead: Int

                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            output.write(buffer, 0, bytesRead)
                            totalBytesRead += bytesRead

                            if (fileLength > 0) {
                                val progress = totalBytesRead.toDouble() / fileLength.toDouble()
                                _downloadProgress.value = progress
                                _downloadStatus.value = DownloadStatus.Downloading(progress)
                            }
                        }
                    }
                }
            }

            _downloadStatus.value = DownloadStatus.Processing

            // Brief processing delay
            withContext(Dispatchers.IO) {
                Thread.sleep(200)
            }

            _downloadStatus.value = DownloadStatus.Completed
            _currentlyDownloading.value = null
            loadDownloadedModels()

        } catch (e: Exception) {
            _downloadStatus.value = DownloadStatus.Failed(e.message ?: "Unknown error")
            _currentlyDownloading.value = null
            throw e
        }
    }

    /**
     * Delete a downloaded model
     */
    fun deleteModel(modelType: OfflineModelType) {
        val modelFile = File(modelsDirectory, modelType.fileName)
        if (modelFile.exists()) {
            modelFile.delete()
        }
        loadDownloadedModels()
    }

    /**
     * Delete all downloaded models
     */
    fun deleteAllModels() {
        modelsDirectory.listFiles()?.forEach { file ->
            file.delete()
        }
        loadDownloadedModels()
    }

    /**
     * Check if a specific model is downloaded
     */
    fun isModelDownloaded(modelType: OfflineModelType): Boolean {
        val modelFile = File(modelsDirectory, modelType.fileName)
        return modelFile.exists()
    }

    /**
     * Get the path to a downloaded model
     */
    fun modelPath(modelType: OfflineModelType): File? {
        val file = File(modelsDirectory, modelType.fileName)
        return if (file.exists()) file else null
    }

    /**
     * Check if offline translation is available for a language pair
     */
    fun canTranslateOffline(sourceCode: String, targetCode: String): Boolean {
        // If we have Whisper, we can transcribe any language
        // If we have NLLB, we can translate between supported languages
        // Without NLLB, Whisper only translates TO English

        if (_downloadedWhisperModel.value == null) return false

        return if (_isNLLBDownloaded.value) {
            // NLLB supports translation between most language pairs
            true
        } else {
            // Whisper alone only translates TO English
            targetCode == "en"
        }
    }

    /**
     * Check if offline speech recognition is available
     */
    fun canRecognizeSpeechOffline(): Boolean {
        return _downloadedWhisperModel.value != null
    }

    /**
     * Get total size of downloaded models
     */
    fun totalDownloadedSize(): Long {
        var totalSize = 0L
        OfflineModelType.entries.forEach { modelType ->
            if (isModelDownloaded(modelType)) {
                totalSize += modelType.downloadSizeBytes
            }
        }
        return totalSize
    }

    /**
     * Get formatted total size string
     */
    fun totalDownloadedSizeFormatted(): String {
        return formatBytes(totalDownloadedSize())
    }

    /**
     * Cancel ongoing download
     */
    fun cancelDownload() {
        _downloadStatus.value = DownloadStatus.Idle
        _downloadProgress.value = 0.0
        _currentlyDownloading.value = null
    }

    // Selected package preference
    var selectedOfflinePackage: OfflineModelPackage?
        get() {
            val id = prefs.getString("selectedOfflinePackage", null) ?: return null
            return OfflineModelPackage.entries.find { it.id == id }
        }
        set(value) {
            prefs.edit().putString("selectedOfflinePackage", value?.id).apply()
        }

    var hasDownloadedModels: Boolean
        get() = prefs.getBoolean("hasDownloadedModels", false)
        set(value) = prefs.edit().putBoolean("hasDownloadedModels", value).apply()

    // MARK: - Private Methods

    private fun loadDownloadedModels() {
        // Check which Whisper model is downloaded (prefer larger)
        _downloadedWhisperModel.value = when {
            isModelDownloaded(OfflineModelType.WHISPER_MEDIUM) -> WhisperModelSize.MEDIUM
            isModelDownloaded(OfflineModelType.WHISPER_SMALL) -> WhisperModelSize.SMALL
            isModelDownloaded(OfflineModelType.WHISPER_TINY) -> WhisperModelSize.TINY
            else -> null
        }

        // Check NLLB
        _isNLLBDownloaded.value = isModelDownloaded(OfflineModelType.NLLB)

        // Update hasDownloadedModels flag
        hasDownloadedModels = _downloadedWhisperModel.value != null || _isNLLBDownloaded.value
    }

    companion object {
        private fun formatBytes(bytes: Long): String {
            if (bytes < 1024) return "$bytes B"
            val kb = bytes / 1024.0
            if (kb < 1024) return "${DecimalFormat("#.#").format(kb)} KB"
            val mb = kb / 1024.0
            if (mb < 1024) return "${DecimalFormat("#.#").format(mb)} MB"
            val gb = mb / 1024.0
            return "${DecimalFormat("#.#").format(gb)} GB"
        }
    }
}

/**
 * Offline model errors
 */
sealed class OfflineModelException(message: String) : Exception(message) {
    object InvalidURL : OfflineModelException("Invalid model download URL")
    class DownloadFailed(details: String) : OfflineModelException("Failed to download model: $details")
    object UnzipFailed : OfflineModelException("Failed to extract model")
    object ModelNotFound : OfflineModelException("Model file not found")
}
