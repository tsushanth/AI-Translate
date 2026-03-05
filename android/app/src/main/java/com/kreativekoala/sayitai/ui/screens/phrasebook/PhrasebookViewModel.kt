package com.kreativekoala.sayitai.ui.screens.phrasebook

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kreativekoala.sayitai.data.repository.Result
import com.kreativekoala.sayitai.data.repository.TranslationRepository
import com.kreativekoala.sayitai.domain.model.Language
import com.kreativekoala.sayitai.domain.model.Phrase
import com.kreativekoala.sayitai.domain.model.PhraseCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PhrasebookUiState(
    val selectedCategory: PhraseCategory? = null,
    val targetLanguage: Language = Language.supportedLanguages.find { it.code == "es" } ?: Language.supportedLanguages.first(),
    val searchQuery: String = "",
    val searchResults: List<Phrase> = emptyList(),
    val translatingPhraseId: String? = null,
    val translations: Map<String, String> = emptyMap(),
    val error: String? = null,
    val showLanguagePicker: Boolean = false
)

@HiltViewModel
class PhrasebookViewModel @Inject constructor(
    private val translationRepository: TranslationRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(PhrasebookUiState())
    val uiState: StateFlow<PhrasebookUiState> = _uiState.asStateFlow()

    private val allPhrases: List<Phrase> by lazy {
        PhraseCategory.categories.flatMap { it.phrases }
    }

    fun selectCategory(category: PhraseCategory) {
        _uiState.update {
            it.copy(
                selectedCategory = category,
                translations = emptyMap()
            )
        }
    }

    fun clearSelectedCategory() {
        _uiState.update {
            it.copy(
                selectedCategory = null,
                translations = emptyMap()
            )
        }
    }

    fun setTargetLanguage(language: Language) {
        _uiState.update {
            it.copy(
                targetLanguage = language,
                showLanguagePicker = false,
                translations = emptyMap()
            )
        }
    }

    fun updateSearchQuery(query: String) {
        _uiState.update { state ->
            val results = if (query.isBlank()) {
                emptyList()
            } else {
                allPhrases.filter { phrase ->
                    phrase.text.contains(query, ignoreCase = true) ||
                            phrase.context?.contains(query, ignoreCase = true) == true
                }
            }
            state.copy(
                searchQuery = query,
                searchResults = results,
                translations = emptyMap()
            )
        }
    }

    fun translatePhrase(phrase: Phrase) {
        // If already translated, just show it
        if (_uiState.value.translations.containsKey(phrase.id)) {
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(translatingPhraseId = phrase.id) }

            val result = translationRepository.translate(
                text = phrase.text,
                sourceLanguage = "en",
                targetLanguage = _uiState.value.targetLanguage.code
            )

            when (result) {
                is Result.Success -> {
                    val translatedText = result.data.translatedText ?: phrase.text
                    _uiState.update { state ->
                        state.copy(
                            translatingPhraseId = null,
                            translations = state.translations + (phrase.id to translatedText)
                        )
                    }
                }
                is Result.Error -> {
                    _uiState.update {
                        it.copy(
                            translatingPhraseId = null,
                            error = result.message
                        )
                    }
                }
                is Result.Loading -> {}
            }
        }
    }

    fun showLanguagePicker(show: Boolean) {
        _uiState.update { it.copy(showLanguagePicker = show) }
    }

    fun dismissError() {
        _uiState.update { it.copy(error = null) }
    }
}
