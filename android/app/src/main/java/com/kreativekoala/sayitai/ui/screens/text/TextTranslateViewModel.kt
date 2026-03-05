package com.kreativekoala.sayitai.ui.screens.text

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kreativekoala.sayitai.data.repository.Result
import com.kreativekoala.sayitai.data.repository.SettingsRepository
import com.kreativekoala.sayitai.data.repository.TranslationRepository
import com.kreativekoala.sayitai.domain.model.Language
import com.kreativekoala.sayitai.domain.model.TranslationEntry
import com.kreativekoala.sayitai.util.AudioPlayerManager
import com.kreativekoala.sayitai.util.AudioPlayerState
import com.kreativekoala.sayitai.util.NetworkMonitor
import com.kreativekoala.sayitai.util.SpeechRecognitionManager
import com.kreativekoala.sayitai.util.SpeechRecognitionState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class TextTranslateUiState(
    val sourceText: String = "",
    val translatedText: String = "",
    val sourceLanguage: Language = Language.AUTO_DETECT,
    val targetLanguage: Language = Language.supportedLanguages.find { it.code == "es" } ?: Language.supportedLanguages.first(),
    val detectedLanguage: Language? = null,
    val isTranslating: Boolean = false,
    val isSourceSpeaking: Boolean = false,
    val isTargetSpeaking: Boolean = false,
    val isListening: Boolean = false,
    val partialSpeechResult: String = "",
    val error: String? = null,
    val showSourceLanguagePicker: Boolean = false,
    val showTargetLanguagePicker: Boolean = false,
    val isOnline: Boolean = true,
    val isOfflineTranslation: Boolean = false
)

@HiltViewModel
class TextTranslateViewModel @Inject constructor(
    private val translationRepository: TranslationRepository,
    private val settingsRepository: SettingsRepository,
    private val speechRecognitionManager: SpeechRecognitionManager,
    private val audioPlayerManager: AudioPlayerManager,
    private val networkMonitor: NetworkMonitor
) : ViewModel() {

    private val _uiState = MutableStateFlow(TextTranslateUiState())
    val uiState: StateFlow<TextTranslateUiState> = _uiState.asStateFlow()

    init {
        // Observe network state
        viewModelScope.launch {
            networkMonitor.isOnline.collect { isOnline ->
                _uiState.update { it.copy(isOnline = isOnline) }
            }
        }

        // Observe speech recognition state
        viewModelScope.launch {
            speechRecognitionManager.state.collect { state ->
                when (state) {
                    is SpeechRecognitionState.Idle -> {
                        _uiState.update { it.copy(isListening = false, partialSpeechResult = "") }
                    }
                    is SpeechRecognitionState.Listening -> {
                        _uiState.update { it.copy(isListening = true) }
                    }
                    is SpeechRecognitionState.Processing -> {
                        _uiState.update { it.copy(isListening = false) }
                    }
                    is SpeechRecognitionState.PartialResult -> {
                        _uiState.update { it.copy(partialSpeechResult = state.text) }
                    }
                    is SpeechRecognitionState.Result -> {
                        _uiState.update {
                            it.copy(
                                sourceText = state.text,
                                isListening = false,
                                partialSpeechResult = ""
                            )
                        }
                        // Auto-translate after speech
                        if (state.text.isNotBlank()) {
                            translate()
                        }
                    }
                    is SpeechRecognitionState.Error -> {
                        _uiState.update {
                            it.copy(
                                isListening = false,
                                error = state.message,
                                partialSpeechResult = ""
                            )
                        }
                    }
                }
            }
        }

        // Observe audio player state
        viewModelScope.launch {
            audioPlayerManager.state.collect { state ->
                when (state) {
                    is AudioPlayerState.Idle -> {
                        _uiState.update { it.copy(isSourceSpeaking = false, isTargetSpeaking = false) }
                    }
                    is AudioPlayerState.Error -> {
                        _uiState.update {
                            it.copy(
                                isSourceSpeaking = false,
                                isTargetSpeaking = false,
                                error = state.message
                            )
                        }
                    }
                    else -> {}
                }
            }
        }
    }

    fun updateSourceText(text: String) {
        _uiState.update { it.copy(sourceText = text, error = null) }
    }

    fun setSourceLanguage(language: Language) {
        _uiState.update {
            it.copy(
                sourceLanguage = language,
                showSourceLanguagePicker = false
            )
        }
        // Re-translate if there's text
        if (_uiState.value.sourceText.isNotBlank()) {
            translate()
        }
    }

    fun setTargetLanguage(language: Language) {
        _uiState.update {
            it.copy(
                targetLanguage = language,
                showTargetLanguagePicker = false
            )
        }
        // Re-translate if there's text
        if (_uiState.value.sourceText.isNotBlank()) {
            translate()
        }
    }

    fun swapLanguages() {
        val currentState = _uiState.value

        // Can't swap if source is auto-detect
        if (currentState.sourceLanguage.code == "auto") {
            // Use detected language if available
            val newSource = currentState.detectedLanguage ?: return
            _uiState.update {
                it.copy(
                    sourceLanguage = newSource,
                    targetLanguage = currentState.sourceLanguage,
                    sourceText = currentState.translatedText,
                    translatedText = currentState.sourceText,
                    detectedLanguage = null
                )
            }
        } else {
            _uiState.update {
                it.copy(
                    sourceLanguage = currentState.targetLanguage,
                    targetLanguage = currentState.sourceLanguage,
                    sourceText = currentState.translatedText,
                    translatedText = currentState.sourceText
                )
            }
        }

        // Re-translate with swapped text
        if (_uiState.value.sourceText.isNotBlank()) {
            translate()
        }
    }

    fun translate() {
        val currentState = _uiState.value
        val text = currentState.sourceText.trim()

        if (text.isBlank()) {
            _uiState.update { it.copy(translatedText = "", error = null) }
            return
        }

        if (text.length > 5000) {
            _uiState.update { it.copy(error = "Text too long. Maximum 5000 characters.") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isTranslating = true, error = null) }

            val provider = settingsRepository.translationProvider.first()

            val result = translationRepository.translate(
                text = text,
                sourceLanguage = currentState.sourceLanguage.code,
                targetLanguage = currentState.targetLanguage.code,
                provider = provider.name.lowercase()
            )

            when (result) {
                is Result.Success -> {
                    val translatedText = result.data.translatedText
                    if (translatedText.isNullOrBlank()) {
                        _uiState.update {
                            it.copy(
                                isTranslating = false,
                                error = "Translation failed - no result received"
                            )
                        }
                        return@launch
                    }

                    val detectedLang = result.data.detectedLanguage?.let {
                        Language.fromCode(it)
                    }

                    _uiState.update {
                        it.copy(
                            translatedText = translatedText,
                            detectedLanguage = detectedLang,
                            isTranslating = false,
                            isOfflineTranslation = result.data.isOffline
                        )
                    }

                    // Save to history
                    val entry = TranslationEntry(
                        sourceText = text,
                        translatedText = translatedText,
                        sourceLanguage = currentState.sourceLanguage.code,
                        targetLanguage = currentState.targetLanguage.code,
                        detectedLanguage = result.data.detectedLanguage
                    )
                    translationRepository.addToHistory(entry)
                }
                is Result.Error -> {
                    _uiState.update {
                        it.copy(
                            isTranslating = false,
                            error = result.message
                        )
                    }
                }
                is Result.Loading -> {}
            }
        }
    }

    fun speakSource() {
        val currentState = _uiState.value
        if (currentState.sourceText.isBlank()) return

        viewModelScope.launch {
            _uiState.update { it.copy(isSourceSpeaking = true) }

            val languageCode = if (currentState.sourceLanguage.code == "auto") {
                currentState.detectedLanguage?.speechLocaleCode ?: "en-US"
            } else {
                currentState.sourceLanguage.speechLocaleCode
            }

            val result = translationRepository.textToSpeech(
                text = currentState.sourceText,
                languageCode = languageCode
            )

            when (result) {
                is Result.Success -> {
                    audioPlayerManager.playAudio(result.data)
                }
                is Result.Error -> {
                    _uiState.update {
                        it.copy(isSourceSpeaking = false, error = result.message)
                    }
                }
                is Result.Loading -> {}
            }
        }
    }

    fun speakTarget() {
        val currentState = _uiState.value
        if (currentState.translatedText.isBlank()) return

        viewModelScope.launch {
            _uiState.update { it.copy(isTargetSpeaking = true) }

            val result = translationRepository.textToSpeech(
                text = currentState.translatedText,
                languageCode = currentState.targetLanguage.speechLocaleCode
            )

            when (result) {
                is Result.Success -> {
                    audioPlayerManager.playAudio(result.data)
                }
                is Result.Error -> {
                    _uiState.update {
                        it.copy(isTargetSpeaking = false, error = result.message)
                    }
                }
                is Result.Loading -> {}
            }
        }
    }

    fun startListening() {
        val currentState = _uiState.value
        val languageCode = if (currentState.sourceLanguage.code == "auto") {
            "en-US" // Default to English for auto-detect
        } else {
            currentState.sourceLanguage.speechLocaleCode
        }
        speechRecognitionManager.startListening(languageCode)
    }

    fun stopListening() {
        speechRecognitionManager.stopListening()
    }

    fun clearText() {
        _uiState.update {
            it.copy(
                sourceText = "",
                translatedText = "",
                detectedLanguage = null,
                error = null
            )
        }
    }

    fun showSourceLanguagePicker(show: Boolean) {
        _uiState.update { it.copy(showSourceLanguagePicker = show) }
    }

    fun showTargetLanguagePicker(show: Boolean) {
        _uiState.update { it.copy(showTargetLanguagePicker = show) }
    }

    fun dismissError() {
        _uiState.update { it.copy(error = null) }
    }

    override fun onCleared() {
        super.onCleared()
        speechRecognitionManager.destroy()
        audioPlayerManager.release()
    }
}
