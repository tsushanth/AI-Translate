package com.kreativekoala.sayitai.data.model

import com.google.gson.annotations.SerializedName

data class TranslationRequest(
    @SerializedName("text")
    val text: String,
    @SerializedName("sourceLanguage")
    val sourceLanguage: String,
    @SerializedName("targetLanguage")
    val targetLanguage: String,
    @SerializedName("deviceId")
    val deviceId: String,
    @SerializedName("provider")
    val provider: String? = null
)

/**
 * API response wrapper that matches the backend response format:
 * {"success":true,"data":{...},"meta":{...}}
 */
data class ApiResponse<T>(
    @SerializedName("success")
    val success: Boolean,
    @SerializedName("data")
    val data: T?,
    @SerializedName("meta")
    val meta: ResponseMeta? = null,
    @SerializedName("error")
    val error: String? = null
)

data class ResponseMeta(
    @SerializedName("requestId")
    val requestId: String? = null,
    @SerializedName("processingTimeMs")
    val processingTimeMs: Int? = null
)

data class TranslationResponseData(
    @SerializedName("translatedText")
    val translatedText: String?,
    @SerializedName("sourceLanguage")
    val sourceLanguage: String,
    @SerializedName("targetLanguage")
    val targetLanguage: String,
    @SerializedName("detectedLanguage")
    val detectedLanguage: String? = null,
    @SerializedName("confidence")
    val confidence: Double? = null,
    @SerializedName("characterCount")
    val characterCount: Int? = null,
    @SerializedName("provider")
    val provider: String? = null
)

/**
 * Domain model for translation responses - used throughout the app
 */
data class TranslationResponse(
    val translatedText: String?,
    val sourceLanguage: String,
    val targetLanguage: String,
    val detectedLanguage: String? = null,
    val confidence: Double? = null,
    val characterCount: Int? = null,
    val requestId: String? = null,
    val processingTimeMs: Int? = null,
    val provider: String? = null,
    // Local-only field for offline translations
    val isOffline: Boolean = false
) {
    companion object {
        fun fromApiResponse(apiResponse: ApiResponse<TranslationResponseData>): TranslationResponse? {
            val data = apiResponse.data ?: return null
            return TranslationResponse(
                translatedText = data.translatedText,
                sourceLanguage = data.sourceLanguage,
                targetLanguage = data.targetLanguage,
                detectedLanguage = data.detectedLanguage,
                confidence = data.confidence,
                characterCount = data.characterCount,
                requestId = apiResponse.meta?.requestId,
                processingTimeMs = apiResponse.meta?.processingTimeMs,
                provider = data.provider,
                isOffline = false
            )
        }
    }
}

data class TTSRequest(
    @SerializedName("text")
    val text: String,
    @SerializedName("languageCode")
    val languageCode: String,
    @SerializedName("speakingRate")
    val speakingRate: Float = 1.0f,
    @SerializedName("deviceId")
    val deviceId: String
)

data class ErrorResponse(
    @SerializedName("error")
    val error: String,
    @SerializedName("code")
    val code: String? = null,
    @SerializedName("details")
    val details: String? = null
)
