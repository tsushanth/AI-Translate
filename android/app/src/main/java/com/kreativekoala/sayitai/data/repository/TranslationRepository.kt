package com.kreativekoala.sayitai.data.repository

import android.util.Log
import com.kreativekoala.sayitai.data.local.TranslationDao
import com.kreativekoala.sayitai.data.local.TranslationEntryEntity
import com.kreativekoala.sayitai.data.model.TranslationRequest
import com.kreativekoala.sayitai.data.model.TranslationResponse
import com.kreativekoala.sayitai.data.model.TTSRequest
import com.kreativekoala.sayitai.data.remote.TranslationApiService
import com.kreativekoala.sayitai.domain.model.TranslationEntry
import com.kreativekoala.sayitai.util.DeviceIdManager
import com.kreativekoala.sayitai.util.NetworkMonitor
import com.kreativekoala.sayitai.util.OfflineTranslationManager
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String, val code: String? = null) : Result<Nothing>()
    data object Loading : Result<Nothing>()
}

@Singleton
class TranslationRepository @Inject constructor(
    private val apiService: TranslationApiService,
    private val translationDao: TranslationDao,
    private val deviceIdManager: DeviceIdManager,
    private val offlineTranslationManager: OfflineTranslationManager,
    private val networkMonitor: NetworkMonitor
) {
    companion object {
        private const val TAG = "TranslationRepository"
        private const val MAX_HISTORY_ENTRIES = 100
    }

    /**
     * Translates text with automatic offline fallback.
     * Uses cloud translation when online, ML Kit offline translation when offline.
     */
    suspend fun translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        provider: String? = null,
        forceOffline: Boolean = false
    ): Result<TranslationResponse> {
        val isOnline = networkMonitor.isOnline.first()

        // Use offline translation if offline or forced
        if (!isOnline || forceOffline) {
            return translateOffline(text, sourceLanguage, targetLanguage)
        }

        // Try cloud translation first
        return try {
            val request = TranslationRequest(
                text = text,
                sourceLanguage = sourceLanguage,
                targetLanguage = targetLanguage,
                deviceId = deviceIdManager.getDeviceId(),
                provider = provider
            )

            val response = apiService.translate(request)

            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse != null && apiResponse.success) {
                    val translationResponse = TranslationResponse.fromApiResponse(apiResponse)
                    if (translationResponse != null) {
                        Result.Success(translationResponse)
                    } else {
                        Log.w(TAG, "Failed to parse translation response, trying offline")
                        translateOffline(text, sourceLanguage, targetLanguage)
                    }
                } else {
                    val errorMsg = apiResponse?.error ?: "Unknown error"
                    Log.w(TAG, "API returned error: $errorMsg, trying offline")
                    translateOffline(text, sourceLanguage, targetLanguage)
                }
            } else {
                val errorBody = response.errorBody()?.string()
                // Fall back to offline on server error
                Log.w(TAG, "Cloud translation failed, trying offline: $errorBody")
                translateOffline(text, sourceLanguage, targetLanguage)
            }
        } catch (e: Exception) {
            // Fall back to offline on network error
            Log.w(TAG, "Network error, trying offline translation: ${e.message}")
            translateOffline(text, sourceLanguage, targetLanguage)
        }
    }

    /**
     * Translates text using ML Kit offline translation
     */
    private suspend fun translateOffline(
        text: String,
        sourceLanguage: String,
        targetLanguage: String
    ): Result<TranslationResponse> {
        // Check if languages are supported
        if (!offlineTranslationManager.isLanguageSupported(sourceLanguage) ||
            !offlineTranslationManager.isLanguageSupported(targetLanguage)) {
            return Result.Error("Language pair not supported for offline translation")
        }

        return try {
            val translatedText = offlineTranslationManager.translate(
                text = text,
                sourceLanguage = sourceLanguage,
                targetLanguage = targetLanguage
            )

            if (translatedText != null) {
                Result.Success(
                    TranslationResponse(
                        translatedText = translatedText,
                        sourceLanguage = sourceLanguage,
                        targetLanguage = targetLanguage,
                        provider = "mlkit_offline",
                        isOffline = true
                    )
                )
            } else {
                Result.Error("Offline translation failed. Please download language models in Settings.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Offline translation error", e)
            Result.Error("Offline translation error: ${e.message}")
        }
    }

    /**
     * Checks if offline translation is available for a language pair
     */
    fun isOfflineAvailable(sourceLanguage: String, targetLanguage: String): Boolean {
        return offlineTranslationManager.isLanguagePairAvailable(sourceLanguage, targetLanguage)
    }

    /**
     * Downloads language models for offline use
     */
    suspend fun downloadOfflineLanguage(languageCode: String): Boolean {
        return offlineTranslationManager.downloadLanguageModel(languageCode)
    }

    /**
     * Gets the list of downloaded offline languages
     */
    fun getDownloadedOfflineLanguages(): Flow<Set<String>> {
        return offlineTranslationManager.downloadedLanguages
    }

    suspend fun textToSpeech(
        text: String,
        languageCode: String,
        speakingRate: Float = 1.0f
    ): Result<ByteArray> {
        return try {
            val request = TTSRequest(
                text = text,
                languageCode = languageCode,
                speakingRate = speakingRate,
                deviceId = deviceIdManager.getDeviceId()
            )

            val response = apiService.textToSpeech(request)

            if (response.isSuccessful) {
                response.body()?.bytes()?.let { audioBytes ->
                    Result.Success(audioBytes)
                } ?: Result.Error("Empty audio response")
            } else {
                Result.Error("TTS request failed", response.code().toString())
            }
        } catch (e: Exception) {
            Result.Error(e.message ?: "Network error occurred")
        }
    }

    // History operations
    fun getAllHistory(): Flow<List<TranslationEntry>> {
        return translationDao.getAllEntries().map { entities ->
            entities.map { it.toDomainModel() }
        }
    }

    fun getFavorites(): Flow<List<TranslationEntry>> {
        return translationDao.getFavorites().map { entities ->
            entities.map { it.toDomainModel() }
        }
    }

    fun searchHistory(query: String): Flow<List<TranslationEntry>> {
        return translationDao.searchEntries(query).map { entities ->
            entities.map { it.toDomainModel() }
        }
    }

    suspend fun addToHistory(entry: TranslationEntry) {
        // Check for duplicate
        val duplicate = translationDao.findDuplicate(
            entry.sourceText,
            entry.sourceLanguage,
            entry.targetLanguage
        )

        if (duplicate != null) {
            // Update the existing entry with new timestamp
            translationDao.update(
                duplicate.copy(
                    translatedText = entry.translatedText,
                    createdAt = entry.createdAt.time
                )
            )
        } else {
            // Check if we need to remove old entries
            val count = translationDao.getCount()
            if (count >= MAX_HISTORY_ENTRIES) {
                val toDelete = count - MAX_HISTORY_ENTRIES + 1
                translationDao.deleteOldestNonFavorites(toDelete)
            }

            translationDao.insert(TranslationEntryEntity.fromDomainModel(entry))
        }
    }

    suspend fun toggleFavorite(id: String) {
        val entries = translationDao.getAllEntries()
        entries.collect { list ->
            list.find { it.id == id }?.let { entry ->
                translationDao.updateFavorite(id, !entry.isFavorite)
            }
        }
    }

    suspend fun setFavorite(id: String, isFavorite: Boolean) {
        translationDao.updateFavorite(id, isFavorite)
    }

    suspend fun deleteEntry(id: String) {
        translationDao.deleteById(id)
    }

    suspend fun clearAllHistory() {
        translationDao.deleteAll()
    }

    suspend fun getHistoryCount(): Int {
        return translationDao.getCount()
    }

    suspend fun getFavoritesCount(): Int {
        return translationDao.getFavoritesCount()
    }
}
