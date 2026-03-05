package com.kreativekoala.sayitai.di

import android.content.Context
import androidx.room.Room
import com.kreativekoala.sayitai.BuildConfig
import com.kreativekoala.sayitai.data.local.AppDatabase
import com.kreativekoala.sayitai.data.local.TranslationDao
import com.kreativekoala.sayitai.data.remote.TranslationApiService
import com.kreativekoala.sayitai.util.DeviceCapabilityChecker
import com.kreativekoala.sayitai.util.NetworkMonitor
import com.kreativekoala.sayitai.util.OfflineModelManager
import com.kreativekoala.sayitai.util.OfflineSpeechRecognitionManager
import com.kreativekoala.sayitai.util.OfflineTranslationManager
import com.kreativekoala.sayitai.util.SpeechRecognitionManager
import com.kreativekoala.sayitai.util.TTSManager
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        val loggingInterceptor = HttpLoggingInterceptor().apply {
            level = if (BuildConfig.DEBUG) {
                HttpLoggingInterceptor.Level.BODY
            } else {
                HttpLoggingInterceptor.Level.NONE
            }
        }

        return OkHttpClient.Builder()
            .addInterceptor(loggingInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }

    @Provides
    @Singleton
    fun provideTranslationApiService(retrofit: Retrofit): TranslationApiService {
        return retrofit.create(TranslationApiService::class.java)
    }

    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            AppDatabase.DATABASE_NAME
        ).build()
    }

    @Provides
    @Singleton
    fun provideTranslationDao(database: AppDatabase): TranslationDao {
        return database.translationDao()
    }

    @Provides
    @Singleton
    fun provideDeviceCapabilityChecker(@ApplicationContext context: Context): DeviceCapabilityChecker {
        return DeviceCapabilityChecker(context)
    }

    @Provides
    @Singleton
    fun provideOfflineModelManager(@ApplicationContext context: Context): OfflineModelManager {
        return OfflineModelManager(context)
    }

    @Provides
    @Singleton
    fun provideTTSManager(
        @ApplicationContext context: Context,
        okHttpClient: OkHttpClient
    ): TTSManager {
        return TTSManager(context, okHttpClient)
    }

    @Provides
    @Singleton
    fun provideNetworkMonitor(@ApplicationContext context: Context): NetworkMonitor {
        return NetworkMonitor(context)
    }

    @Provides
    @Singleton
    fun provideOfflineTranslationManager(@ApplicationContext context: Context): OfflineTranslationManager {
        return OfflineTranslationManager(context)
    }

    @Provides
    @Singleton
    fun provideOfflineSpeechRecognitionManager(@ApplicationContext context: Context): OfflineSpeechRecognitionManager {
        return OfflineSpeechRecognitionManager(context)
    }

    @Provides
    @Singleton
    fun provideSpeechRecognitionManager(
        @ApplicationContext context: Context,
        networkMonitor: NetworkMonitor,
        offlineSpeechManager: OfflineSpeechRecognitionManager
    ): SpeechRecognitionManager {
        return SpeechRecognitionManager(context, networkMonitor, offlineSpeechManager)
    }
}
