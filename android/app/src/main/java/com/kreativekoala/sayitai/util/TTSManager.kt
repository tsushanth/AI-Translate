package com.kreativekoala.sayitai.util

import android.content.Context
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * TTS Mode for the app
 */
enum class TTSMode(val id: String) {
    AUTOMATIC("automatic"),   // Use cloud if Pro & online, device otherwise
    CLOUD_ONLY("cloud"),      // Always use cloud (requires Pro)
    DEVICE_ONLY("device");    // Always use device TTS (works offline)

    val displayName: String
        get() = when (this) {
            AUTOMATIC -> "Automatic"
            CLOUD_ONLY -> "Cloud (Pro)"
            DEVICE_ONLY -> "Device"
        }

    val description: String
        get() = when (this) {
            AUTOMATIC -> "Uses premium voices when online, device voices offline"
            CLOUD_ONLY -> "Always use premium AI voices (requires internet)"
            DEVICE_ONLY -> "Always use device voices (works offline)"
        }

    companion object {
        fun fromId(id: String): TTSMode = entries.find { it.id == id } ?: AUTOMATIC
    }
}

/**
 * TTS error types
 */
sealed class TTSException(message: String) : Exception(message) {
    object LanguageNotSupported : TTSException("Language not supported")
    object SynthesisError : TTSException("Speech synthesis failed")
    class NetworkError(message: String) : TTSException(message)
    object NotInitialized : TTSException("TTS not initialized")
}

/**
 * Listener for TTS events
 */
interface TTSListener {
    fun onStart()
    fun onDone()
    fun onError(error: TTSException)
}

/**
 * Unified TTS Manager that intelligently switches between cloud and device TTS
 * - Pro users: Get cloud TTS with natural AI voices when online
 * - Free users: Get device TTS (Android TextToSpeech) which works offline
 * - Automatic fallback: If cloud fails, falls back to device TTS
 */
@Singleton
class TTSManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val okHttpClient: OkHttpClient
) {
    private val prefs: SharedPreferences = context.getSharedPreferences("tts_prefs", Context.MODE_PRIVATE)

    // StateFlows for observable state
    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking.asStateFlow()

    private val _currentMode = MutableStateFlow(TTSMode.AUTOMATIC)
    val currentMode: StateFlow<TTSMode> = _currentMode.asStateFlow()

    private val _isOnline = MutableStateFlow(true)
    val isOnline: StateFlow<Boolean> = _isOnline.asStateFlow()

    private val _lastUsedService = MutableStateFlow("")
    val lastUsedService: StateFlow<String> = _lastUsedService.asStateFlow()

    private val _isInitialized = MutableStateFlow(false)
    val isInitialized: StateFlow<Boolean> = _isInitialized.asStateFlow()

    // Private properties
    private var textToSpeech: TextToSpeech? = null
    private var listener: TTSListener? = null
    private var pendingText: String? = null
    private var pendingLanguage: String? = null
    private var pendingRate: Float? = null
    private var currentUtteranceId: String? = null
    private val audioManager = android.media.AudioManager::class.java

    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    // TODO: Replace with actual premium status check from billing
    private val isPremium: Boolean
        get() = false  // Placeholder - integrate with billing

    init {
        loadSavedMode()
        initializeDeviceTTS()
        startNetworkMonitoring()
    }

    // MARK: - Public Methods

    /**
     * Speaks the given text using the appropriate TTS service
     */
    suspend fun speak(text: String, languageCode: String, rate: Float = 1.0f) {
        // Stop any current speech
        stop()

        // Store pending request for fallback
        pendingText = text
        pendingLanguage = languageCode
        pendingRate = rate

        // Determine which service to use
        val useCloud = when (_currentMode.value) {
            TTSMode.AUTOMATIC -> isPremium && _isOnline.value
            TTSMode.CLOUD_ONLY -> _isOnline.value
            TTSMode.DEVICE_ONLY -> false
        }

        if (useCloud) {
            try {
                speakWithCloud(text, languageCode, rate)
                _lastUsedService.value = if (isPremium) "Cloud (Premium)" else "Cloud"
            } catch (e: Exception) {
                // Fallback to device TTS
                speakWithDevice(text, languageCode, rate)
                _lastUsedService.value = "Device (Fallback)"
            }
        } else {
            speakWithDevice(text, languageCode, rate)
            _lastUsedService.value = "Device"
        }
    }

    /**
     * Stops any current speech
     */
    fun stop() {
        textToSpeech?.stop()
        _isSpeaking.value = false
        pendingText = null
        pendingLanguage = null
        pendingRate = null
    }

    /**
     * Sets the TTS mode
     */
    fun setMode(mode: TTSMode) {
        _currentMode.value = mode
        prefs.edit().putString("ttsMode", mode.id).apply()
    }

    /**
     * Returns available modes based on subscription status
     */
    val availableModes: List<TTSMode>
        get() = if (isPremium) TTSMode.entries else listOf(TTSMode.DEVICE_ONLY)

    /**
     * Returns whether cloud TTS is currently available
     */
    val isCloudAvailable: Boolean
        get() = isPremium && _isOnline.value

    /**
     * Returns whether device TTS is available for a language
     */
    fun isDeviceTTSAvailable(languageCode: String): Boolean {
        val locale = Locale.forLanguageTag(languageCode)
        val result = textToSpeech?.isLanguageAvailable(locale) ?: TextToSpeech.LANG_NOT_SUPPORTED
        return result >= TextToSpeech.LANG_AVAILABLE
    }

    /**
     * Set the TTS listener
     */
    fun setListener(listener: TTSListener?) {
        this.listener = listener
    }

    /**
     * Speak and wait for completion (suspending function)
     */
    suspend fun speakAsync(text: String, languageCode: String, rate: Float = 1.0f) {
        suspendCancellableCoroutine<Unit> { continuation ->
            val asyncListener = object : TTSListener {
                override fun onStart() {}

                override fun onDone() {
                    if (continuation.isActive) {
                        continuation.resume(Unit)
                    }
                }

                override fun onError(error: TTSException) {
                    if (continuation.isActive) {
                        continuation.resumeWithException(error)
                    }
                }
            }

            val previousListener = listener
            listener = asyncListener

            continuation.invokeOnCancellation {
                stop()
                listener = previousListener
            }

            kotlinx.coroutines.runBlocking {
                speak(text, languageCode, rate)
            }
        }
    }

    /**
     * Clean up resources
     */
    fun shutdown() {
        textToSpeech?.shutdown()
        textToSpeech = null
        _isInitialized.value = false
    }

    // MARK: - Private Methods

    private fun loadSavedMode() {
        val modeId = prefs.getString("ttsMode", TTSMode.AUTOMATIC.id) ?: TTSMode.AUTOMATIC.id
        _currentMode.value = TTSMode.fromId(modeId)
    }

    private fun initializeDeviceTTS() {
        textToSpeech = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                _isInitialized.value = true

                textToSpeech?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        if (utteranceId == currentUtteranceId) {
                            _isSpeaking.value = true
                            listener?.onStart()
                        }
                    }

                    override fun onDone(utteranceId: String?) {
                        if (utteranceId == currentUtteranceId) {
                            _isSpeaking.value = false
                            listener?.onDone()
                            clearPending()
                        }
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        if (utteranceId == currentUtteranceId) {
                            _isSpeaking.value = false
                            listener?.onError(TTSException.SynthesisError)
                        }
                    }

                    override fun onError(utteranceId: String?, errorCode: Int) {
                        if (utteranceId == currentUtteranceId) {
                            _isSpeaking.value = false
                            listener?.onError(TTSException.SynthesisError)
                        }
                    }
                })
            } else {
                _isInitialized.value = false
            }
        }
    }

    private fun startNetworkMonitoring() {
        val networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                _isOnline.value = true
            }

            override fun onLost(network: Network) {
                _isOnline.value = false
            }

            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                _isOnline.value = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            }
        }

        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        try {
            connectivityManager.registerNetworkCallback(request, networkCallback)
        } catch (e: Exception) {
            // Handle security exception on some devices
            _isOnline.value = true
        }

        // Initial check
        val activeNetwork = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
        _isOnline.value = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
    }

    private suspend fun speakWithCloud(text: String, languageCode: String, rate: Float) {
        withContext(Dispatchers.IO) {
            try {
                // TODO: Replace with actual cloud TTS API endpoint
                val mediaType = "application/json".toMediaType()
                val requestBody = """{"text": "$text", "language": "$languageCode", "rate": $rate}""".toRequestBody(mediaType)

                val request = Request.Builder()
                    .url("https://api.sayitai.app/tts")
                    .post(requestBody)
                    .build()

                val response = okHttpClient.newCall(request).execute()

                if (!response.isSuccessful) {
                    throw TTSException.NetworkError("HTTP ${response.code}")
                }

                // Save audio to temp file and play
                val audioData = response.body?.bytes()
                    ?: throw TTSException.NetworkError("Empty response")

                val tempFile = File.createTempFile("tts_", ".mp3", context.cacheDir)
                FileOutputStream(tempFile).use { it.write(audioData) }

                // Play the audio using MediaPlayer
                withContext(Dispatchers.Main) {
                    playAudioFile(tempFile)
                }

            } catch (e: Exception) {
                throw TTSException.NetworkError(e.message ?: "Unknown error")
            }
        }
    }

    private fun playAudioFile(file: File) {
        val mediaPlayer = android.media.MediaPlayer().apply {
            setDataSource(file.absolutePath)
            prepare()
            setOnCompletionListener {
                _isSpeaking.value = false
                listener?.onDone()
                clearPending()
                it.release()
                file.delete()
            }
            setOnErrorListener { _, _, _ ->
                _isSpeaking.value = false
                listener?.onError(TTSException.SynthesisError)
                release()
                file.delete()
                true
            }
        }

        _isSpeaking.value = true
        listener?.onStart()
        mediaPlayer.start()
    }

    private fun speakWithDevice(text: String, languageCode: String, rate: Float) {
        val tts = textToSpeech ?: run {
            listener?.onError(TTSException.NotInitialized)
            return
        }

        val locale = Locale.forLanguageTag(languageCode)
        val langResult = tts.setLanguage(locale)

        if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
            // Try with just the language code (without region)
            val baseLocale = Locale(locale.language)
            val baseResult = tts.setLanguage(baseLocale)

            if (baseResult == TextToSpeech.LANG_MISSING_DATA || baseResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                listener?.onError(TTSException.LanguageNotSupported)
                return
            }
        }

        tts.setSpeechRate(rate)

        currentUtteranceId = UUID.randomUUID().toString()
        val params = android.os.Bundle().apply {
            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
        }

        tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, currentUtteranceId)
    }

    private fun clearPending() {
        pendingText = null
        pendingLanguage = null
        pendingRate = null
    }
}
