package com.kreativekoala.sayitai.util

import android.content.Context
import android.util.Log
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Manages offline translation using Google ML Kit Translate.
 * Handles model downloads, caching, and translation operations.
 */
@Singleton
class OfflineTranslationManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        private const val TAG = "OfflineTranslationMgr"

        // Map our language codes to ML Kit language codes
        private val LANGUAGE_CODE_MAP = mapOf(
            "en" to TranslateLanguage.ENGLISH,
            "es" to TranslateLanguage.SPANISH,
            "fr" to TranslateLanguage.FRENCH,
            "de" to TranslateLanguage.GERMAN,
            "it" to TranslateLanguage.ITALIAN,
            "pt" to TranslateLanguage.PORTUGUESE,
            "ru" to TranslateLanguage.RUSSIAN,
            "zh" to TranslateLanguage.CHINESE,
            "ja" to TranslateLanguage.JAPANESE,
            "ko" to TranslateLanguage.KOREAN,
            "ar" to TranslateLanguage.ARABIC,
            "hi" to TranslateLanguage.HINDI,
            "nl" to TranslateLanguage.DUTCH,
            "pl" to TranslateLanguage.POLISH,
            "tr" to TranslateLanguage.TURKISH,
            "vi" to TranslateLanguage.VIETNAMESE,
            "th" to TranslateLanguage.THAI,
            "sv" to TranslateLanguage.SWEDISH,
            "da" to TranslateLanguage.DANISH,
            "fi" to TranslateLanguage.FINNISH,
            "no" to TranslateLanguage.NORWEGIAN,
            "cs" to TranslateLanguage.CZECH,
            "el" to TranslateLanguage.GREEK,
            "he" to TranslateLanguage.HEBREW,
            "id" to TranslateLanguage.INDONESIAN,
            "ms" to TranslateLanguage.MALAY,
            "ro" to TranslateLanguage.ROMANIAN,
            "uk" to TranslateLanguage.UKRAINIAN,
            "hu" to TranslateLanguage.HUNGARIAN,
            "bn" to TranslateLanguage.BENGALI
        )
    }

    private val modelManager = RemoteModelManager.getInstance()
    private val translatorCache = mutableMapOf<String, Translator>()

    private val _downloadedLanguages = MutableStateFlow<Set<String>>(emptySet())
    val downloadedLanguages: StateFlow<Set<String>> = _downloadedLanguages.asStateFlow()

    private val _downloadProgress = MutableStateFlow<Map<String, Float>>(emptyMap())
    val downloadProgress: StateFlow<Map<String, Float>> = _downloadProgress.asStateFlow()

    private val _isDownloading = MutableStateFlow(false)
    val isDownloading: StateFlow<Boolean> = _isDownloading.asStateFlow()

    init {
        refreshDownloadedLanguages()
    }

    /**
     * Refreshes the list of downloaded language models
     */
    fun refreshDownloadedLanguages() {
        modelManager.getDownloadedModels(TranslateRemoteModel::class.java)
            .addOnSuccessListener { models ->
                val languages = models.mapNotNull { model ->
                    LANGUAGE_CODE_MAP.entries.find { it.value == model.language }?.key
                }.toSet()
                _downloadedLanguages.value = languages
                Log.d(TAG, "Downloaded languages: $languages")
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to get downloaded models", e)
            }
    }

    /**
     * Checks if a language pair is available for offline translation
     */
    fun isLanguagePairAvailable(sourceLanguage: String, targetLanguage: String): Boolean {
        val downloaded = _downloadedLanguages.value
        return downloaded.contains(sourceLanguage) && downloaded.contains(targetLanguage)
    }

    /**
     * Checks if offline translation is supported for the given language
     */
    fun isLanguageSupported(languageCode: String): Boolean {
        return LANGUAGE_CODE_MAP.containsKey(languageCode)
    }

    /**
     * Downloads language models for offline use
     */
    suspend fun downloadLanguageModel(languageCode: String): Boolean {
        val mlKitLanguage = LANGUAGE_CODE_MAP[languageCode]
            ?: run {
                Log.e(TAG, "Language not supported: $languageCode")
                return false
            }

        return try {
            _isDownloading.value = true
            updateDownloadProgress(languageCode, 0f)

            val model = TranslateRemoteModel.Builder(mlKitLanguage).build()
            val conditions = DownloadConditions.Builder()
                .requireWifi()
                .build()

            suspendCancellableCoroutine { continuation ->
                modelManager.download(model, conditions)
                    .addOnSuccessListener {
                        updateDownloadProgress(languageCode, 1f)
                        refreshDownloadedLanguages()
                        Log.d(TAG, "Downloaded language model: $languageCode")
                        continuation.resume(true)
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Failed to download language model: $languageCode", e)
                        removeDownloadProgress(languageCode)
                        continuation.resume(false)
                    }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to download language model: $languageCode", e)
            removeDownloadProgress(languageCode)
            false
        } finally {
            _isDownloading.value = false
        }
    }

    /**
     * Downloads multiple language models
     */
    suspend fun downloadLanguageModels(languageCodes: List<String>): Map<String, Boolean> {
        val results = mutableMapOf<String, Boolean>()
        for (code in languageCodes) {
            results[code] = downloadLanguageModel(code)
        }
        return results
    }

    /**
     * Deletes a downloaded language model
     */
    suspend fun deleteLanguageModel(languageCode: String): Boolean {
        val mlKitLanguage = LANGUAGE_CODE_MAP[languageCode] ?: return false

        return try {
            val model = TranslateRemoteModel.Builder(mlKitLanguage).build()

            suspendCancellableCoroutine { continuation ->
                modelManager.deleteDownloadedModel(model)
                    .addOnSuccessListener {
                        // Close any cached translators using this language
                        translatorCache.entries.removeIf { entry ->
                            if (entry.key.contains(languageCode)) {
                                entry.value.close()
                                true
                            } else {
                                false
                            }
                        }
                        refreshDownloadedLanguages()
                        Log.d(TAG, "Deleted language model: $languageCode")
                        continuation.resume(true)
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Failed to delete language model: $languageCode", e)
                        continuation.resume(false)
                    }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete language model: $languageCode", e)
            false
        }
    }

    /**
     * Translates text offline using ML Kit
     */
    suspend fun translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String
    ): String? {
        val sourceMlKitLang = LANGUAGE_CODE_MAP[sourceLanguage]
        val targetMlKitLang = LANGUAGE_CODE_MAP[targetLanguage]

        if (sourceMlKitLang == null || targetMlKitLang == null) {
            Log.e(TAG, "Language not supported: source=$sourceLanguage, target=$targetLanguage")
            return null
        }

        return try {
            val translator = getOrCreateTranslator(sourceMlKitLang, targetMlKitLang)

            // Ensure models are downloaded
            ensureModelsDownloaded(translator)

            // Perform translation
            suspendCancellableCoroutine { continuation ->
                translator.translate(text)
                    .addOnSuccessListener { translatedText ->
                        continuation.resume(translatedText)
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Translation failed", e)
                        continuation.resumeWithException(e)
                    }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Translation error", e)
            null
        }
    }

    private fun getOrCreateTranslator(sourceLanguage: String, targetLanguage: String): Translator {
        val key = "${sourceLanguage}_$targetLanguage"
        return translatorCache.getOrPut(key) {
            val options = TranslatorOptions.Builder()
                .setSourceLanguage(sourceLanguage)
                .setTargetLanguage(targetLanguage)
                .build()
            Translation.getClient(options)
        }
    }

    private suspend fun ensureModelsDownloaded(translator: Translator) {
        val conditions = DownloadConditions.Builder()
            .requireWifi()
            .build()

        suspendCancellableCoroutine<Unit> { continuation ->
            translator.downloadModelIfNeeded(conditions)
                .addOnSuccessListener {
                    continuation.resume(Unit)
                }
                .addOnFailureListener { e ->
                    continuation.resumeWithException(e)
                }
        }
    }

    private fun updateDownloadProgress(languageCode: String, progress: Float) {
        _downloadProgress.value = _downloadProgress.value.toMutableMap().apply {
            this[languageCode] = progress
        }
    }

    private fun removeDownloadProgress(languageCode: String) {
        _downloadProgress.value = _downloadProgress.value.toMutableMap().apply {
            remove(languageCode)
        }
    }

    /**
     * Gets the estimated size of a language model in MB
     */
    fun getEstimatedModelSize(languageCode: String): Int {
        // ML Kit language models are approximately 30MB each
        return 30
    }

    /**
     * Gets all supported languages for offline translation
     */
    fun getSupportedLanguages(): List<String> {
        return LANGUAGE_CODE_MAP.keys.toList()
    }

    /**
     * Closes all translators and releases resources
     */
    fun close() {
        translatorCache.values.forEach { it.close() }
        translatorCache.clear()
    }
}
