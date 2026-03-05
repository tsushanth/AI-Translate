package com.kreativekoala.sayitai.util

import android.content.Context
import android.media.MediaPlayer
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import javax.inject.Inject
import javax.inject.Singleton

sealed class AudioPlayerState {
    data object Idle : AudioPlayerState()
    data object Loading : AudioPlayerState()
    data object Playing : AudioPlayerState()
    data class Error(val message: String) : AudioPlayerState()
}

@Singleton
class AudioPlayerManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private var mediaPlayer: MediaPlayer? = null

    private val _state = MutableStateFlow<AudioPlayerState>(AudioPlayerState.Idle)
    val state: StateFlow<AudioPlayerState> = _state.asStateFlow()

    suspend fun playAudio(audioBytes: ByteArray) {
        withContext(Dispatchers.IO) {
            try {
                _state.value = AudioPlayerState.Loading

                // Stop any currently playing audio
                stopPlaying()

                // Write audio bytes to temp file
                val tempFile = File.createTempFile("tts_audio", ".mp3", context.cacheDir)
                FileOutputStream(tempFile).use { fos ->
                    fos.write(audioBytes)
                }

                withContext(Dispatchers.Main) {
                    mediaPlayer = MediaPlayer().apply {
                        setDataSource(tempFile.absolutePath)
                        setOnPreparedListener {
                            _state.value = AudioPlayerState.Playing
                            start()
                        }
                        setOnCompletionListener {
                            _state.value = AudioPlayerState.Idle
                            release()
                            mediaPlayer = null
                            tempFile.delete()
                        }
                        setOnErrorListener { _, what, extra ->
                            _state.value = AudioPlayerState.Error("Playback error: $what, $extra")
                            tempFile.delete()
                            true
                        }
                        prepareAsync()
                    }
                }
            } catch (e: Exception) {
                _state.value = AudioPlayerState.Error(e.message ?: "Failed to play audio")
            }
        }
    }

    fun stopPlaying() {
        mediaPlayer?.let {
            if (it.isPlaying) {
                it.stop()
            }
            it.release()
        }
        mediaPlayer = null
        _state.value = AudioPlayerState.Idle
    }

    fun release() {
        stopPlaying()
    }
}
