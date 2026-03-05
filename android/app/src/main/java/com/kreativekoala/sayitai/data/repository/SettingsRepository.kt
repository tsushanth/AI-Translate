package com.kreativekoala.sayitai.data.repository

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.kreativekoala.sayitai.ui.theme.AppTheme
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.settingsDataStore by preferencesDataStore(name = "settings")

enum class TranslationProvider(val displayName: String, val description: String) {
    GOOGLE("Google Translate", "Fast and reliable translation"),
    DEEPL("DeepL", "More natural phrasing for European languages")
}

@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        private val TRANSLATION_PROVIDER_KEY = stringPreferencesKey("translation_provider")
        private val AUTO_DETECT_KEY = booleanPreferencesKey("auto_detect_language")
        private val HAPTIC_FEEDBACK_KEY = booleanPreferencesKey("haptic_feedback")
        private val APP_THEME_KEY = stringPreferencesKey("app_theme")
        private val HAS_SEEN_ONBOARDING_KEY = booleanPreferencesKey("has_seen_onboarding")
    }

    val translationProvider: Flow<TranslationProvider> = context.settingsDataStore.data
        .map { preferences ->
            val providerName = preferences[TRANSLATION_PROVIDER_KEY] ?: TranslationProvider.GOOGLE.name
            TranslationProvider.valueOf(providerName)
        }

    val autoDetectLanguage: Flow<Boolean> = context.settingsDataStore.data
        .map { preferences ->
            preferences[AUTO_DETECT_KEY] ?: true
        }

    val hapticFeedback: Flow<Boolean> = context.settingsDataStore.data
        .map { preferences ->
            preferences[HAPTIC_FEEDBACK_KEY] ?: true
        }

    val appTheme: Flow<AppTheme> = context.settingsDataStore.data
        .map { preferences ->
            val themeName = preferences[APP_THEME_KEY] ?: AppTheme.DARK.name
            AppTheme.valueOf(themeName)
        }

    val hasSeenOnboarding: Flow<Boolean> = context.settingsDataStore.data
        .map { preferences ->
            preferences[HAS_SEEN_ONBOARDING_KEY] ?: false
        }

    suspend fun setTranslationProvider(provider: TranslationProvider) {
        context.settingsDataStore.edit { preferences ->
            preferences[TRANSLATION_PROVIDER_KEY] = provider.name
        }
    }

    suspend fun setAutoDetectLanguage(enabled: Boolean) {
        context.settingsDataStore.edit { preferences ->
            preferences[AUTO_DETECT_KEY] = enabled
        }
    }

    suspend fun setHapticFeedback(enabled: Boolean) {
        context.settingsDataStore.edit { preferences ->
            preferences[HAPTIC_FEEDBACK_KEY] = enabled
        }
    }

    suspend fun setAppTheme(theme: AppTheme) {
        context.settingsDataStore.edit { preferences ->
            preferences[APP_THEME_KEY] = theme.name
        }
    }

    suspend fun setHasSeenOnboarding(hasSeen: Boolean) {
        context.settingsDataStore.edit { preferences ->
            preferences[HAS_SEEN_ONBOARDING_KEY] = hasSeen
        }
    }
}
