package com.kreativekoala.sayitai.ui.screens.camera

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kreativekoala.sayitai.data.repository.Result
import com.kreativekoala.sayitai.data.repository.TranslationRepository
import com.kreativekoala.sayitai.domain.model.Language
import com.kreativekoala.sayitai.util.NetworkMonitor
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CameraTranslateUiState(
    val detectedText: String = "",
    val translatedText: String = "",
    val targetLanguage: Language = Language.supportedLanguages.find { it.code == "es" } ?: Language.supportedLanguages.first(),
    val isFlashOn: Boolean = false,
    val isTranslating: Boolean = false,
    val error: String? = null,
    val showLanguagePicker: Boolean = false,
    val isOnline: Boolean = true
)

@HiltViewModel
class CameraTranslateViewModel @Inject constructor(
    private val translationRepository: TranslationRepository,
    private val networkMonitor: NetworkMonitor
) : ViewModel() {

    private val _uiState = MutableStateFlow(CameraTranslateUiState())
    val uiState: StateFlow<CameraTranslateUiState> = _uiState.asStateFlow()

    private var lastDetectedText = ""

    init {
        // Observe network state
        viewModelScope.launch {
            networkMonitor.isOnline.collect { isOnline ->
                _uiState.update { it.copy(isOnline = isOnline) }
            }
        }
    }

    fun onTextDetected(text: String) {
        // Only update if text changed significantly
        if (text != lastDetectedText && text.length > 3) {
            lastDetectedText = text
            _uiState.update { it.copy(detectedText = text, translatedText = "") }
        }
    }

    fun translate() {
        val text = _uiState.value.detectedText.trim()
        if (text.isBlank()) return

        viewModelScope.launch {
            _uiState.update { it.copy(isTranslating = true, error = null) }

            val result = translationRepository.translate(
                text = text,
                sourceLanguage = "auto",
                targetLanguage = _uiState.value.targetLanguage.code
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
                    _uiState.update {
                        it.copy(
                            translatedText = translatedText,
                            isTranslating = false
                        )
                    }
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

    fun setTargetLanguage(language: Language) {
        _uiState.update {
            it.copy(
                targetLanguage = language,
                showLanguagePicker = false,
                translatedText = ""
            )
        }
    }

    fun toggleFlash() {
        _uiState.update { it.copy(isFlashOn = !it.isFlashOn) }
    }

    fun showLanguagePicker(show: Boolean) {
        _uiState.update { it.copy(showLanguagePicker = show) }
    }

    fun dismissError() {
        _uiState.update { it.copy(error = null) }
    }
}
