package com.kreativekoala.sayitai.domain.model

import java.util.Date
import java.util.UUID

data class TranslationEntry(
    val id: String = UUID.randomUUID().toString(),
    val sourceText: String,
    val translatedText: String,
    val sourceLanguage: String,
    val targetLanguage: String,
    val detectedLanguage: String? = null,
    val createdAt: Date = Date(),
    val isFavorite: Boolean = false
) {
    val sourceLanguageDisplay: String
        get() = Language.fromCode(detectedLanguage ?: sourceLanguage).displayName

    val targetLanguageDisplay: String
        get() = Language.fromCode(targetLanguage).displayName

    val relativeTime: String
        get() {
            val now = Date()
            val diff = now.time - createdAt.time
            val seconds = diff / 1000
            val minutes = seconds / 60
            val hours = minutes / 60
            val days = hours / 24

            return when {
                seconds < 60 -> "Just now"
                minutes < 60 -> "${minutes}m ago"
                hours < 24 -> "${hours}h ago"
                days < 7 -> "${days}d ago"
                else -> {
                    val format = java.text.SimpleDateFormat("MMM d", java.util.Locale.getDefault())
                    format.format(createdAt)
                }
            }
        }
}
