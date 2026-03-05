package com.kreativekoala.sayitai.util

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

sealed class SpeechRecognitionState {
    data object Idle : SpeechRecognitionState()
    data object Listening : SpeechRecognitionState()
    data object Processing : SpeechRecognitionState()
    data class Result(val text: String, val isOffline: Boolean = false) : SpeechRecognitionState()
    data class PartialResult(val text: String) : SpeechRecognitionState()
    data class Error(val message: String) : SpeechRecognitionState()
}

enum class SpeechRecognitionMode {
    AUTOMATIC,      // Auto-switch based on network status
    ONLINE_ONLY,    // Force online recognition
    OFFLINE_ONLY    // Force offline recognition
}

@Singleton
class SpeechRecognitionManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val networkMonitor: NetworkMonitor,
    private val offlineSpeechManager: OfflineSpeechRecognitionManager
) {
    companion object {
        private const val TAG = "SpeechRecognitionMgr"
        private const val MAX_RETRY_ATTEMPTS = 1
        private const val RETRY_DELAY_MS = 200L
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var speechRecognizer: SpeechRecognizer? = null
    private var isUsingOffline = false
    private var currentLanguageCode: String? = null
    private var retryCount = 0

    private val _state = MutableStateFlow<SpeechRecognitionState>(SpeechRecognitionState.Idle)
    val state: StateFlow<SpeechRecognitionState> = _state.asStateFlow()

    private val _isAvailable = MutableStateFlow(SpeechRecognizer.isRecognitionAvailable(context))
    val isAvailable: StateFlow<Boolean> = _isAvailable.asStateFlow()

    private val _mode = MutableStateFlow(SpeechRecognitionMode.AUTOMATIC)
    val mode: StateFlow<SpeechRecognitionMode> = _mode.asStateFlow()

    private val _isOfflineAvailable = MutableStateFlow(false)
    val isOfflineAvailable: StateFlow<Boolean> = _isOfflineAvailable.asStateFlow()

    init {
        // Monitor offline speech recognition state
        scope.launch {
            offlineSpeechManager.state.collect { offlineState ->
                if (isUsingOffline) {
                    _state.value = when (offlineState) {
                        is SpeechRecognitionState.Result ->
                            SpeechRecognitionState.Result(offlineState.text, isOffline = true)
                        else -> offlineState
                    }
                }
            }
        }

        // Update offline availability
        scope.launch {
            offlineSpeechManager.downloadedModels.collect { models ->
                _isOfflineAvailable.value = models.isNotEmpty()
            }
        }
    }

    /**
     * Sets the recognition mode
     */
    fun setMode(mode: SpeechRecognitionMode) {
        _mode.value = mode
    }

    /**
     * Starts listening with automatic online/offline switching
     */
    fun startListening(languageCode: String) {
        currentLanguageCode = languageCode
        retryCount = 0
        startListeningInternal(languageCode)
    }

    private fun startListeningInternal(languageCode: String) {
        scope.launch {
            val isOnline = networkMonitor.isOnline.first()
            val currentMode = _mode.value

            val shouldUseOffline = when (currentMode) {
                SpeechRecognitionMode.AUTOMATIC -> !isOnline && offlineSpeechManager.isModelAvailable(languageCode)
                SpeechRecognitionMode.ONLINE_ONLY -> false
                SpeechRecognitionMode.OFFLINE_ONLY -> true
            }

            if (shouldUseOffline) {
                startOfflineListening(languageCode)
            } else {
                startOnlineListening(languageCode)
            }
        }
    }

    private suspend fun startOfflineListening(languageCode: String) {
        Log.d(TAG, "Starting offline recognition for: $languageCode")
        isUsingOffline = true

        // Load the model if not already loaded
        val modelLoaded = offlineSpeechManager.loadModel(languageCode)
        if (!modelLoaded) {
            _state.value = SpeechRecognitionState.Error(
                "Offline model not available for this language. Download it in Settings."
            )
            return
        }

        offlineSpeechManager.startListening(languageCode)
    }

    private fun startOnlineListening(languageCode: String) {
        Log.d(TAG, "Starting online recognition for: $languageCode")
        isUsingOffline = false

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            _state.value = SpeechRecognitionState.Error("Speech recognition not available")
            return
        }

        stopListening()

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    _state.value = SpeechRecognitionState.Listening
                }

                override fun onBeginningOfSpeech() {}

                override fun onRmsChanged(rmsdB: Float) {}

                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    _state.value = SpeechRecognitionState.Processing
                }

                override fun onError(error: Int) {
                    Log.w(TAG, "Speech recognition error: $error, retry count: $retryCount")

                    // Retry on transient errors (CLIENT error often happens on first use)
                    val isRetryableError = error == SpeechRecognizer.ERROR_CLIENT ||
                            error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY

                    if (isRetryableError && retryCount < MAX_RETRY_ATTEMPTS) {
                        retryCount++
                        Log.d(TAG, "Retrying speech recognition (attempt $retryCount)")
                        // Clean up current recognizer
                        speechRecognizer?.destroy()
                        speechRecognizer = null
                        // Retry after a short delay
                        scope.launch {
                            kotlinx.coroutines.delay(RETRY_DELAY_MS)
                            currentLanguageCode?.let { startListeningInternal(it) }
                        }
                        return
                    }

                    val message = when (error) {
                        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                        SpeechRecognizer.ERROR_CLIENT -> "Speech recognition not ready. Please try again."
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission required"
                        SpeechRecognizer.ERROR_NETWORK -> "Network error"
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                        SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy. Please try again."
                        SpeechRecognizer.ERROR_SERVER -> "Server error"
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
                        else -> "Speech recognition error ($error)"
                    }

                    // Try offline fallback on network errors
                    if ((error == SpeechRecognizer.ERROR_NETWORK ||
                         error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT ||
                         error == SpeechRecognizer.ERROR_SERVER) &&
                        _mode.value == SpeechRecognitionMode.AUTOMATIC) {
                        Log.w(TAG, "Online recognition failed, no offline fallback configured")
                    }

                    _state.value = SpeechRecognitionState.Error(message)
                }

                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = matches?.firstOrNull() ?: ""
                    _state.value = if (text.isNotEmpty()) {
                        SpeechRecognitionState.Result(text, isOffline = false)
                    } else {
                        SpeechRecognitionState.Error("No speech detected")
                    }
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = matches?.firstOrNull() ?: ""
                    if (text.isNotEmpty()) {
                        _state.value = SpeechRecognitionState.PartialResult(text)
                    }
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageCode)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

        speechRecognizer?.startListening(intent)
    }

    fun stopListening() {
        if (isUsingOffline) {
            offlineSpeechManager.stopListening()
        } else {
            speechRecognizer?.stopListening()
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
        _state.value = SpeechRecognitionState.Idle
    }

    fun resetState() {
        _state.value = SpeechRecognitionState.Idle
        offlineSpeechManager.resetState()
    }

    /**
     * Checks if offline recognition is available for a language
     */
    fun isOfflineModelAvailable(languageCode: String): Boolean {
        return offlineSpeechManager.isModelAvailable(languageCode)
    }

    /**
     * Downloads an offline model for a language
     */
    suspend fun downloadOfflineModel(languageCode: String): Boolean {
        return offlineSpeechManager.downloadModel(languageCode)
    }

    /**
     * Gets downloaded offline models
     */
    fun getDownloadedOfflineModels(): StateFlow<Set<String>> {
        return offlineSpeechManager.downloadedModels
    }

    fun destroy() {
        stopListening()
        offlineSpeechManager.destroy()
    }
}
