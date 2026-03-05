package com.kreativekoala.sayitai.ui.screens.history

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kreativekoala.sayitai.data.repository.TranslationRepository
import com.kreativekoala.sayitai.domain.model.TranslationEntry
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HistoryUiState(
    val entries: List<TranslationEntry> = emptyList(),
    val favorites: List<TranslationEntry> = emptyList(),
    val searchQuery: String = "",
    val isFavoritesOnly: Boolean = false
)

@HiltViewModel
class HistoryViewModel @Inject constructor(
    private val translationRepository: TranslationRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(HistoryUiState())
    val uiState: StateFlow<HistoryUiState> = _uiState.asStateFlow()

    private val searchQueryFlow = MutableStateFlow("")

    init {
        // Collect all history
        viewModelScope.launch {
            translationRepository.getAllHistory().collect { entries ->
                _uiState.update { it.copy(entries = entries) }
            }
        }

        // Collect favorites
        viewModelScope.launch {
            translationRepository.getFavorites().collect { favorites ->
                _uiState.update { it.copy(favorites = favorites) }
            }
        }

        // Handle search
        viewModelScope.launch {
            searchQueryFlow
                .debounce(300)
                .distinctUntilChanged()
                .collect { query ->
                    if (query.isBlank()) {
                        translationRepository.getAllHistory().collect { entries ->
                            _uiState.update { it.copy(entries = entries) }
                        }
                    } else {
                        translationRepository.searchHistory(query).collect { entries ->
                            _uiState.update { it.copy(entries = entries) }
                        }
                    }
                }
        }
    }

    fun setFavoritesOnly(favoritesOnly: Boolean) {
        _uiState.update { it.copy(isFavoritesOnly = favoritesOnly) }
    }

    fun updateSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
        searchQueryFlow.value = query
    }

    fun toggleFavorite(id: String) {
        viewModelScope.launch {
            val entry = _uiState.value.entries.find { it.id == id }
                ?: _uiState.value.favorites.find { it.id == id }

            entry?.let {
                translationRepository.setFavorite(id, !it.isFavorite)
            }
        }
    }

    fun deleteEntry(id: String) {
        viewModelScope.launch {
            translationRepository.deleteEntry(id)
        }
    }
}
