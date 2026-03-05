package com.kreativekoala.sayitai.domain.model

import java.util.Date
import java.util.UUID

enum class ConversationSide {
    LEFT,
    RIGHT
}

data class ConversationMessage(
    val id: String = UUID.randomUUID().toString(),
    val originalText: String,
    val translatedText: String,
    val side: ConversationSide,
    val sourceLanguage: Language,
    val targetLanguage: Language,
    val timestamp: Date = Date()
)
