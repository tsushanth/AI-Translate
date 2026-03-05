package com.kreativekoala.sayitai.util

import android.content.Context
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.StorageService
import java.io.File
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Offline speech recognition using Vosk.
 * Provides WhisperKit-like functionality for Android.
 */
@Singleton
class OfflineSpeechRecognitionManager @Inject constructor(
    @ApplicationContext private val context: Context
) : RecognitionListener {

    companion object {
        private const val TAG = "OfflineSpeechRecog"
        private const val SAMPLE_RATE = 16000.0f

        // Vosk model download URLs (small models for faster downloads)
        private val MODEL_URLS = mapOf(
            "en" to "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip",
            "es" to "https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip",
            "fr" to "https://alphacephei.com/vosk/models/vosk-model-small-fr-0.22.zip",
            "de" to "https://alphacephei.com/vosk/models/vosk-model-small-de-0.15.zip",
            "it" to "https://alphacephei.com/vosk/models/vosk-model-small-it-0.22.zip",
            "pt" to "https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip",
            "ru" to "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip",
            "zh" to "https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip",
            "ja" to "https://alphacephei.com/vosk/models/vosk-model-small-ja-0.22.zip",
            "ko" to "https://alphacephei.com/vosk/models/vosk-model-small-ko-0.22.zip",
            "hi" to "https://alphacephei.com/vosk/models/vosk-model-small-hi-0.22.zip",
            "nl" to "https://alphacephei.com/vosk/models/vosk-model-small-nl-0.22.zip",
            "pl" to "https://alphacephei.com/vosk/models/vosk-model-small-pl-0.22.zip",
            "tr" to "https://alphacephei.com/vosk/models/vosk-model-small-tr-0.3.zip",
            "vi" to "https://alphacephei.com/vosk/models/vosk-model-small-vn-0.4.zip",
            "uk" to "https://alphacephei.com/vosk/models/vosk-model-small-uk-v3-small.zip"
        )

        // Model sizes in MB (approximate)
        private val MODEL_SIZES = mapOf(
            "en" to 40,
            "es" to 39,
            "fr" to 41,
            "de" to 45,
            "it" to 39,
            "pt" to 31,
            "ru" to 45,
            "zh" to 42,
            "ja" to 48,
            "ko" to 62,
            "hi" to 42,
            "nl" to 39,
            "pl" to 50,
            "tr" to 35,
            "vi" to 32,
            "uk" to 133
        )
    }

    private var model: Model? = null
    private var speechService: SpeechService? = null
    private var currentLanguage: String? = null

    private val _state = MutableStateFlow<SpeechRecognitionState>(SpeechRecognitionState.Idle)
    val state: StateFlow<SpeechRecognitionState> = _state.asStateFlow()

    private val _downloadedModels = MutableStateFlow<Set<String>>(emptySet())
    val downloadedModels: StateFlow<Set<String>> = _downloadedModels.asStateFlow()

    private val _downloadProgress = MutableStateFlow<Map<String, Float>>(emptyMap())
    val downloadProgress: StateFlow<Map<String, Float>> = _downloadProgress.asStateFlow()

    private val _isModelLoaded = MutableStateFlow(false)
    val isModelLoaded: StateFlow<Boolean> = _isModelLoaded.asStateFlow()

    init {
        refreshDownloadedModels()
    }

    /**
     * Refreshes the list of downloaded models
     */
    fun refreshDownloadedModels() {
        val modelsDir = getModelsDirectory()
        val downloaded = mutableSetOf<String>()

        MODEL_URLS.keys.forEach { langCode ->
            val modelDir = File(modelsDir, "vosk-model-$langCode")
            if (modelDir.exists() && modelDir.isDirectory) {
                downloaded.add(langCode)
            }
        }

        _downloadedModels.value = downloaded
        Log.d(TAG, "Downloaded models: $downloaded")
    }

    /**
     * Checks if a language model is available
     */
    fun isModelAvailable(languageCode: String): Boolean {
        val normalizedCode = normalizeLanguageCode(languageCode)
        return _downloadedModels.value.contains(normalizedCode)
    }

    /**
     * Downloads a language model
     * Note: Vosk models are expected to be bundled in assets or downloaded separately.
     * This implementation checks for bundled models and unpacks them.
     */
    suspend fun downloadModel(languageCode: String): Boolean {
        val normalizedCode = normalizeLanguageCode(languageCode)
        if (!MODEL_URLS.containsKey(normalizedCode)) {
            Log.e(TAG, "No model available for language: $languageCode")
            return false
        }

        return withContext(Dispatchers.IO) {
            try {
                updateDownloadProgress(normalizedCode, 0f)

                val modelsDir = getModelsDirectory()
                val modelDir = File(modelsDir, "vosk-model-$normalizedCode")

                // Delete existing model if present
                if (modelDir.exists()) {
                    modelDir.deleteRecursively()
                }

                updateDownloadProgress(normalizedCode, 0.5f)

                // Try to unpack from assets (models should be bundled in APK)
                // StorageService.unpack uses a completion callback, not progress callback
                var success = false
                var error: Exception? = null

                val latch = java.util.concurrent.CountDownLatch(1)

                StorageService.unpack(
                    context,
                    "model-$normalizedCode",
                    modelDir.absolutePath,
                    { model ->
                        // Success callback - model is ready
                        Log.d(TAG, "Model unpacked successfully: $normalizedCode")
                        success = true
                        latch.countDown()
                    },
                    { exception ->
                        // Error callback
                        Log.e(TAG, "Failed to unpack model: $normalizedCode", exception)
                        error = exception
                        latch.countDown()
                    }
                )

                // Wait for unpack to complete (with timeout)
                latch.await(5, java.util.concurrent.TimeUnit.MINUTES)

                if (success) {
                    updateDownloadProgress(normalizedCode, 1f)
                    refreshDownloadedModels()
                    true
                } else {
                    removeDownloadProgress(normalizedCode)
                    Log.e(TAG, "Model unpack failed for: $normalizedCode", error)
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to download model: $normalizedCode", e)
                removeDownloadProgress(normalizedCode)
                false
            }
        }
    }

    /**
     * Loads the model for the specified language
     */
    suspend fun loadModel(languageCode: String): Boolean {
        val normalizedCode = normalizeLanguageCode(languageCode)

        if (!isModelAvailable(normalizedCode)) {
            Log.e(TAG, "Model not downloaded for: $normalizedCode")
            return false
        }

        // Don't reload if same model is already loaded
        if (currentLanguage == normalizedCode && model != null) {
            return true
        }

        return withContext(Dispatchers.IO) {
            try {
                // Close existing model
                model?.close()
                model = null

                val modelDir = File(getModelsDirectory(), "vosk-model-$normalizedCode")
                model = Model(modelDir.absolutePath)
                currentLanguage = normalizedCode
                _isModelLoaded.value = true
                Log.d(TAG, "Model loaded for: $normalizedCode")
                true
            } catch (e: IOException) {
                Log.e(TAG, "Failed to load model: $normalizedCode", e)
                _isModelLoaded.value = false
                false
            }
        }
    }

    /**
     * Starts speech recognition
     */
    fun startListening(languageCode: String) {
        val normalizedCode = normalizeLanguageCode(languageCode)

        if (model == null || currentLanguage != normalizedCode) {
            _state.value = SpeechRecognitionState.Error("Model not loaded. Call loadModel() first.")
            return
        }

        stopListening()

        try {
            val recognizer = Recognizer(model, SAMPLE_RATE)
            speechService = SpeechService(recognizer, SAMPLE_RATE)
            speechService?.startListening(this)
            _state.value = SpeechRecognitionState.Listening
            Log.d(TAG, "Started listening with language: $normalizedCode")
        } catch (e: IOException) {
            Log.e(TAG, "Failed to start speech service", e)
            _state.value = SpeechRecognitionState.Error("Failed to start speech recognition")
        }
    }

    /**
     * Stops speech recognition
     */
    fun stopListening() {
        speechService?.stop()
        speechService = null
        _state.value = SpeechRecognitionState.Idle
    }

    /**
     * Resets the recognition state
     */
    fun resetState() {
        _state.value = SpeechRecognitionState.Idle
    }

    /**
     * Deletes a downloaded model
     */
    suspend fun deleteModel(languageCode: String): Boolean {
        val normalizedCode = normalizeLanguageCode(languageCode)

        // Unload if it's the current model
        if (currentLanguage == normalizedCode) {
            model?.close()
            model = null
            currentLanguage = null
            _isModelLoaded.value = false
        }

        return withContext(Dispatchers.IO) {
            try {
                val modelDir = File(getModelsDirectory(), "vosk-model-$normalizedCode")
                if (modelDir.exists()) {
                    modelDir.deleteRecursively()
                }
                refreshDownloadedModels()
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to delete model: $normalizedCode", e)
                false
            }
        }
    }

    /**
     * Gets the estimated size of a model in MB
     */
    fun getModelSize(languageCode: String): Int {
        val normalizedCode = normalizeLanguageCode(languageCode)
        return MODEL_SIZES[normalizedCode] ?: 40 // Default 40MB
    }

    /**
     * Gets all supported languages
     */
    fun getSupportedLanguages(): List<String> {
        return MODEL_URLS.keys.toList()
    }

    /**
     * Releases all resources
     */
    fun destroy() {
        stopListening()
        model?.close()
        model = null
        currentLanguage = null
        _isModelLoaded.value = false
    }

    // RecognitionListener callbacks

    override fun onPartialResult(hypothesis: String?) {
        hypothesis?.let {
            val text = extractTextFromJson(it)
            if (text.isNotEmpty()) {
                _state.value = SpeechRecognitionState.PartialResult(text)
            }
        }
    }

    override fun onResult(hypothesis: String?) {
        hypothesis?.let {
            val text = extractTextFromJson(it)
            if (text.isNotEmpty()) {
                _state.value = SpeechRecognitionState.Result(text)
            } else {
                _state.value = SpeechRecognitionState.Error("No speech detected")
            }
        }
    }

    override fun onFinalResult(hypothesis: String?) {
        hypothesis?.let {
            val text = extractTextFromJson(it)
            if (text.isNotEmpty()) {
                _state.value = SpeechRecognitionState.Result(text)
            }
        }
        _state.value = SpeechRecognitionState.Processing
    }

    override fun onError(exception: Exception?) {
        Log.e(TAG, "Recognition error", exception)
        _state.value = SpeechRecognitionState.Error(exception?.message ?: "Recognition error")
    }

    override fun onTimeout() {
        _state.value = SpeechRecognitionState.Error("Speech timeout")
    }

    // Helper functions

    private fun getModelsDirectory(): File {
        val modelsDir = File(context.filesDir, "vosk-models")
        if (!modelsDir.exists()) {
            modelsDir.mkdirs()
        }
        return modelsDir
    }

    private fun normalizeLanguageCode(code: String): String {
        // Convert codes like "en-US" to "en"
        return code.split("-").first().lowercase()
    }

    private fun extractTextFromJson(json: String): String {
        // Vosk returns JSON like {"text": "hello world"} or {"partial": "hello"}
        return try {
            val textMatch = Regex("\"text\"\\s*:\\s*\"([^\"]*)\"").find(json)
            val partialMatch = Regex("\"partial\"\\s*:\\s*\"([^\"]*)\"").find(json)
            textMatch?.groupValues?.get(1)
                ?: partialMatch?.groupValues?.get(1)
                ?: ""
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse recognition result", e)
            ""
        }
    }

    private fun updateDownloadProgress(languageCode: String, progress: Float) {
        _downloadProgress.value = _downloadProgress.value.toMutableMap().apply {
            this[languageCode] = progress
        }
    }

    private fun removeDownloadProgress(languageCode: String) {
        _downloadProgress.value = _downloadProgress.value.toMutableMap().apply {
            remove(languageCode)
        }
    }
}
