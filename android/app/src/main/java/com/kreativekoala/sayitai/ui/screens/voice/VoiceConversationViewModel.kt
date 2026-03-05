package com.kreativekoala.sayitai.ui.screens.voice

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kreativekoala.sayitai.data.repository.Result
import com.kreativekoala.sayitai.data.repository.TranslationRepository
import com.kreativekoala.sayitai.domain.model.ConversationMessage
import com.kreativekoala.sayitai.domain.model.ConversationSide
import com.kreativekoala.sayitai.domain.model.Language
import com.kreativekoala.sayitai.util.AudioPlayerManager
import com.kreativekoala.sayitai.util.SpeechRecognitionManager
import com.kreativekoala.sayitai.util.SpeechRecognitionState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class VoiceConversationUiState(
    val leftLanguage: Language = Language.supportedLanguages.find { it.code == "en" } ?: Language.supportedLanguages.first(),
    val rightLanguage: Language = Language.supportedLanguages.find { it.code == "es" } ?: Language.supportedLanguages[1],
    val messages: List<ConversationMessage> = emptyList(),
    val isListening: Boolean = false,
    val activeSide: ConversationSide? = null,
    val partialSpeechResult: String = "",
    val isTranslating: Boolean = false,
    val isSpeaking: Boolean = false,
    val error: String? = null,
    val showLeftLanguagePicker: Boolean = false,
    val showRightLanguagePicker: Boolean = false
)

@HiltViewModel
class VoiceConversationViewModel @Inject constructor(
    private val translationRepository: TranslationRepository,
    private val speechRecognitionManager: SpeechRecognitionManager,
    private val audioPlayerManager: AudioPlayerManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(VoiceConversationUiState())
    val uiState: StateFlow<VoiceConversationUiState> = _uiState.asStateFlow()

    init {
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
                        _uiState.update { it.copy(isListening = false, isTranslating = true) }
                    }
                    is SpeechRecognitionState.PartialResult -> {
                        _uiState.update { it.copy(partialSpeechResult = state.text) }
                    }
                    is SpeechRecognitionState.Result -> {
                        _uiState.update { it.copy(partialSpeechResult = "") }
                        if (state.text.isNotBlank()) {
                            translateAndAddMessage(state.text)
                        }
                    }
                    is SpeechRecognitionState.Error -> {
                        _uiState.update {
                            it.copy(
                                isListening = false,
                                isTranslating = false,
                                error = state.message
                            )
                        }
                    }
                }
            }
        }
    }

    fun startListening(side: ConversationSide) {
        val currentState = _uiState.value
        val language = when (side) {
            ConversationSide.LEFT -> currentState.leftLanguage
            ConversationSide.RIGHT -> currentState.rightLanguage
        }

        _uiState.update { it.copy(activeSide = side) }
        speechRecognitionManager.startListening(language.speechLocaleCode)
    }

    fun stopListening() {
        speechRecognitionManager.stopListening()
        _uiState.update { it.copy(activeSide = null) }
    }

    private fun translateAndAddMessage(text: String) {
        val currentState = _uiState.value
        val activeSide = currentState.activeSide ?: return

        val (sourceLanguage, targetLanguage) = when (activeSide) {
            ConversationSide.LEFT -> currentState.leftLanguage to currentState.rightLanguage
            ConversationSide.RIGHT -> currentState.rightLanguage to currentState.leftLanguage
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isTranslating = true) }

            val result = translationRepository.translate(
                text = text,
                sourceLanguage = sourceLanguage.code,
                targetLanguage = targetLanguage.code
            )

            when (result) {
                is Result.Success -> {
                    val translatedText = result.data.translatedText
                    if (translatedText.isNullOrBlank()) {
                        _uiState.update {
                            it.copy(
                                isTranslating = false,
                                error = "Translation failed - no result received",
                                activeSide = null
                            )
                        }
                        return@launch
                    }

                    val message = ConversationMessage(
                        originalText = text,
                        translatedText = translatedText,
                        side = activeSide,
                        sourceLanguage = sourceLanguage,
                        targetLanguage = targetLanguage
                    )

                    _uiState.update {
                        it.copy(
                            messages = it.messages + message,
                            isTranslating = false,
                            activeSide = null
                        )
                    }

                    // Auto-speak the translation
                    speakMessage(message)
                }
                is Result.Error -> {
                    _uiState.update {
                        it.copy(
                            isTranslating = false,
                            error = result.message,
                            activeSide = null
                        )
                    }
                }
                is Result.Loading -> {}
            }
        }
    }

    fun speakMessage(message: ConversationMessage) {
        viewModelScope.launch {
            _uiState.update { it.copy(isSpeaking = true) }

            val result = translationRepository.textToSpeech(
                text = message.translatedText,
                languageCode = message.targetLanguage.speechLocaleCode
            )

            when (result) {
                is Result.Success -> {
                    audioPlayerManager.playAudio(result.data)
                }
                is Result.Error -> {
                    _uiState.update { it.copy(isSpeaking = false, error = result.message) }
                }
                is Result.Loading -> {}
            }

            _uiState.update { it.copy(isSpeaking = false) }
        }
    }

    fun setLeftLanguage(language: Language) {
        _uiState.update { it.copy(leftLanguage = language, showLeftLanguagePicker = false) }
    }

    fun setRightLanguage(language: Language) {
        _uiState.update { it.copy(rightLanguage = language, showRightLanguagePicker = false) }
    }

    fun showLeftLanguagePicker(show: Boolean) {
        _uiState.update { it.copy(showLeftLanguagePicker = show) }
    }

    fun showRightLanguagePicker(show: Boolean) {
        _uiState.update { it.copy(showRightLanguagePicker = show) }
    }

    fun clearConversation() {
        _uiState.update { it.copy(messages = emptyList()) }
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
