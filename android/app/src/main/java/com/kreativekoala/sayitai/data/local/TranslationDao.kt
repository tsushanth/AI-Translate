package com.kreativekoala.sayitai.data.local

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface TranslationDao {
    @Query("SELECT * FROM translation_history ORDER BY createdAt DESC")
    fun getAllEntries(): Flow<List<TranslationEntryEntity>>

    @Query("SELECT * FROM translation_history WHERE isFavorite = 1 ORDER BY createdAt DESC")
    fun getFavorites(): Flow<List<TranslationEntryEntity>>

    @Query("SELECT * FROM translation_history WHERE sourceText LIKE '%' || :query || '%' OR translatedText LIKE '%' || :query || '%' ORDER BY createdAt DESC")
    fun searchEntries(query: String): Flow<List<TranslationEntryEntity>>

    @Query("SELECT COUNT(*) FROM translation_history")
    suspend fun getCount(): Int

    @Query("SELECT COUNT(*) FROM translation_history WHERE isFavorite = 1")
    suspend fun getFavoritesCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entry: TranslationEntryEntity)

    @Update
    suspend fun update(entry: TranslationEntryEntity)

    @Query("UPDATE translation_history SET isFavorite = :isFavorite WHERE id = :id")
    suspend fun updateFavorite(id: String, isFavorite: Boolean)

    @Query("DELETE FROM translation_history WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM translation_history WHERE isFavorite = 0")
    suspend fun deleteNonFavorites()

    @Query("DELETE FROM translation_history")
    suspend fun deleteAll()

    @Query("SELECT * FROM translation_history WHERE sourceText = :sourceText AND sourceLanguage = :sourceLanguage AND targetLanguage = :targetLanguage LIMIT 1")
    suspend fun findDuplicate(sourceText: String, sourceLanguage: String, targetLanguage: String): TranslationEntryEntity?

    @Query("DELETE FROM translation_history WHERE id IN (SELECT id FROM translation_history WHERE isFavorite = 0 ORDER BY createdAt ASC LIMIT :count)")
    suspend fun deleteOldestNonFavorites(count: Int)
}
