package com.kreativekoala.sayitai.ui.screens.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kreativekoala.sayitai.data.repository.SettingsRepository
import com.kreativekoala.sayitai.data.repository.TranslationProvider
import com.kreativekoala.sayitai.data.repository.TranslationRepository
import com.kreativekoala.sayitai.ui.theme.AppTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val translationProvider: TranslationProvider = TranslationProvider.GOOGLE,
    val autoDetectLanguage: Boolean = true,
    val hapticFeedback: Boolean = true,
    val appTheme: AppTheme = AppTheme.DARK,
    val historyCount: Int = 0,
    val favoritesCount: Int = 0
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository,
    private val translationRepository: TranslationRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        // Collect settings
        viewModelScope.launch {
            combine(
                settingsRepository.translationProvider,
                settingsRepository.autoDetectLanguage,
                settingsRepository.hapticFeedback,
                settingsRepository.appTheme
            ) { provider, autoDetect, haptic, theme ->
                _uiState.value.copy(
                    translationProvider = provider,
                    autoDetectLanguage = autoDetect,
                    hapticFeedback = haptic,
                    appTheme = theme
                )
            }.collect { state ->
                _uiState.update { it.copy(
                    translationProvider = state.translationProvider,
                    autoDetectLanguage = state.autoDetectLanguage,
                    hapticFeedback = state.hapticFeedback,
                    appTheme = state.appTheme
                )}
            }
        }

        // Load history counts
        refreshCounts()
    }

    private fun refreshCounts() {
        viewModelScope.launch {
            val historyCount = translationRepository.getHistoryCount()
            val favoritesCount = translationRepository.getFavoritesCount()
            _uiState.update {
                it.copy(
                    historyCount = historyCount,
                    favoritesCount = favoritesCount
                )
            }
        }
    }

    fun setTranslationProvider(provider: TranslationProvider) {
        viewModelScope.launch {
            settingsRepository.setTranslationProvider(provider)
        }
    }

    fun setAutoDetectLanguage(enabled: Boolean) {
        viewModelScope.launch {
            settingsRepository.setAutoDetectLanguage(enabled)
        }
    }

    fun setHapticFeedback(enabled: Boolean) {
        viewModelScope.launch {
            settingsRepository.setHapticFeedback(enabled)
        }
    }

    fun setAppTheme(theme: AppTheme) {
        viewModelScope.launch {
            settingsRepository.setAppTheme(theme)
        }
    }

    fun clearAllHistory() {
        viewModelScope.launch {
            translationRepository.clearAllHistory()
            refreshCounts()
        }
    }
}
