package com.kreativekoala.sayitai.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.kreativekoala.sayitai.domain.model.TranslationEntry
import java.util.Date

@Entity(tableName = "translation_history")
data class TranslationEntryEntity(
    @PrimaryKey
    val id: String,
    val sourceText: String,
    val translatedText: String,
    val sourceLanguage: String,
    val targetLanguage: String,
    val detectedLanguage: String?,
    val createdAt: Long,
    val isFavorite: Boolean
) {
    fun toDomainModel(): TranslationEntry {
        return TranslationEntry(
            id = id,
            sourceText = sourceText,
            translatedText = translatedText,
            sourceLanguage = sourceLanguage,
            targetLanguage = targetLanguage,
            detectedLanguage = detectedLanguage,
            createdAt = Date(createdAt),
            isFavorite = isFavorite
        )
    }

    companion object {
        fun fromDomainModel(entry: TranslationEntry): TranslationEntryEntity {
            return TranslationEntryEntity(
                id = entry.id,
                sourceText = entry.sourceText,
                translatedText = entry.translatedText,
                sourceLanguage = entry.sourceLanguage,
                targetLanguage = entry.targetLanguage,
                detectedLanguage = entry.detectedLanguage,
                createdAt = entry.createdAt.time,
                isFavorite = entry.isFavorite
            )
        }
    }
}
