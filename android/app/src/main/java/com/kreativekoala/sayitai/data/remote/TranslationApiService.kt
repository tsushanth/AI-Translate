package com.kreativekoala.sayitai.data.remote

import com.kreativekoala.sayitai.data.model.ApiResponse
import com.kreativekoala.sayitai.data.model.TranslationRequest
import com.kreativekoala.sayitai.data.model.TranslationResponseData
import com.kreativekoala.sayitai.data.model.TTSRequest
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

interface TranslationApiService {
    @POST("/v1/translate")
    suspend fun translate(@Body request: TranslationRequest): Response<ApiResponse<TranslationResponseData>>

    @POST("/v1/tts")
    suspend fun textToSpeech(@Body request: TTSRequest): Response<ResponseBody>
}
