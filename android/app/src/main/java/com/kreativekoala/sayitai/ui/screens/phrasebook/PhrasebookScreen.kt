package com.kreativekoala.sayitai.ui.screens.phrasebook

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.kreativekoala.sayitai.domain.model.Language
import com.kreativekoala.sayitai.domain.model.Phrase
import com.kreativekoala.sayitai.domain.model.PhraseCategory
import com.kreativekoala.sayitai.ui.components.LanguagePickerSheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PhrasebookScreen(
    viewModel: PhrasebookViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            Toast.makeText(context, it, Toast.LENGTH_LONG).show()
            viewModel.dismissError()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Top bar
        TopAppBar(
            title = {
                if (uiState.selectedCategory != null) {
                    Text(
                        uiState.selectedCategory!!.name,
                        style = MaterialTheme.typography.headlineMedium
                    )
                } else {
                    Text(
                        "Phrasebook",
                        style = MaterialTheme.typography.headlineMedium
                    )
                }
            },
            navigationIcon = {
                if (uiState.selectedCategory != null) {
                    IconButton(onClick = { viewModel.clearSelectedCategory() }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            },
            actions = {
                // Target language selector
                TextButton(
                    onClick = { viewModel.showLanguagePicker(true) }
                ) {
                    Text(
                        text = "${uiState.targetLanguage.flagEmoji} ${uiState.targetLanguage.name}"
                    )
                    Icon(
                        Icons.Default.KeyboardArrowDown,
                        contentDescription = null
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.background
            )
        )

        // Search bar
        OutlinedTextField(
            value = uiState.searchQuery,
            onValueChange = { viewModel.updateSearchQuery(it) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            placeholder = { Text("Search phrases") },
            leadingIcon = {
                Icon(Icons.Default.Search, contentDescription = null)
            },
            trailingIcon = {
                if (uiState.searchQuery.isNotBlank()) {
                    IconButton(onClick = { viewModel.updateSearchQuery("") }) {
                        Icon(Icons.Default.Clear, contentDescription = "Clear")
                    }
                }
            },
            singleLine = true,
            shape = RoundedCornerShape(12.dp)
        )

        if (uiState.searchQuery.isNotBlank()) {
            // Search results
            SearchResults(
                phrases = uiState.searchResults,
                targetLanguage = uiState.targetLanguage,
                onPhraseClick = { viewModel.translatePhrase(it) },
                translatingPhraseId = uiState.translatingPhraseId,
                translations = uiState.translations
            )
        } else if (uiState.selectedCategory != null) {
            // Category phrases
            PhraseList(
                phrases = uiState.selectedCategory!!.phrases,
                targetLanguage = uiState.targetLanguage,
                onPhraseClick = { viewModel.translatePhrase(it) },
                translatingPhraseId = uiState.translatingPhraseId,
                translations = uiState.translations
            )
        } else {
            // Category grid
            CategoryGrid(
                categories = PhraseCategory.categories,
                onCategoryClick = { viewModel.selectCategory(it) }
            )
        }
    }

    // Language picker
    if (uiState.showLanguagePicker) {
        LanguagePickerSheet(
            languages = Language.supportedLanguages,
            selectedLanguage = uiState.targetLanguage,
            onLanguageSelected = { viewModel.setTargetLanguage(it) },
            onDismiss = { viewModel.showLanguagePicker(false) },
            title = "Target Language"
        )
    }
}

@Composable
private fun CategoryGrid(
    categories: List<PhraseCategory>,
    onCategoryClick: (PhraseCategory) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(vertical = 8.dp)
    ) {
        items(categories) { category ->
            CategoryCard(
                category = category,
                onClick = { onCategoryClick(category) }
            )
        }
    }
}

@Composable
private fun CategoryCard(
    category: PhraseCategory,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1.2f)
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = category.color.copy(alpha = 0.15f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            val icon = when (category.icon) {
                "chat_bubble" -> Icons.Default.ChatBubble
                "flight" -> Icons.Default.Flight
                "restaurant" -> Icons.Default.Restaurant
                "emergency" -> Icons.Default.LocalHospital
                "shopping_cart" -> Icons.Default.ShoppingCart
                "hotel" -> Icons.Default.Hotel
                else -> Icons.Default.Category
            }

            Icon(
                icon,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = category.color
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = category.name,
                style = MaterialTheme.typography.titleMedium,
                color = category.color,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "${category.phrases.size} phrases",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun PhraseList(
    phrases: List<Phrase>,
    targetLanguage: Language,
    onPhraseClick: (Phrase) -> Unit,
    translatingPhraseId: String?,
    translations: Map<String, String>
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(phrases) { phrase ->
            PhraseCard(
                phrase = phrase,
                targetLanguage = targetLanguage,
                onClick = { onPhraseClick(phrase) },
                isTranslating = translatingPhraseId == phrase.id,
                translation = translations[phrase.id]
            )
        }
    }
}

@Composable
private fun SearchResults(
    phrases: List<Phrase>,
    targetLanguage: Language,
    onPhraseClick: (Phrase) -> Unit,
    translatingPhraseId: String?,
    translations: Map<String, String>
) {
    if (phrases.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    Icons.Default.SearchOff,
                    contentDescription = null,
                    modifier = Modifier.size(48.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "No phrases found",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    } else {
        PhraseList(
            phrases = phrases,
            targetLanguage = targetLanguage,
            onPhraseClick = onPhraseClick,
            translatingPhraseId = translatingPhraseId,
            translations = translations
        )
    }
}

@Composable
private fun PhraseCard(
    phrase: Phrase,
    targetLanguage: Language,
    onClick: () -> Unit,
    isTranslating: Boolean,
    translation: String?
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = phrase.text,
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.weight(1f)
                )

                if (isTranslating) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Icon(
                        Icons.Default.Translate,
                        contentDescription = "Translate",
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
            }

            phrase.context?.let { context ->
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = context,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            translation?.let {
                Spacer(modifier = Modifier.height(8.dp))
                Divider()
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = targetLanguage.flagEmoji,
                        style = MaterialTheme.typography.labelMedium
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }
    }
}
