package com.kreativekoala.sayitai.util

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

private val Context.deviceIdDataStore by preferencesDataStore(name = "device_id")

@Singleton
class DeviceIdManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        private val DEVICE_ID_KEY = stringPreferencesKey("device_id")
    }

    private var cachedDeviceId: String? = null

    fun getDeviceId(): String {
        cachedDeviceId?.let { return it }

        return runBlocking {
            val storedId = context.deviceIdDataStore.data
                .map { preferences -> preferences[DEVICE_ID_KEY] }
                .first()

            if (storedId != null) {
                cachedDeviceId = storedId
                storedId
            } else {
                val newId = UUID.randomUUID().toString()
                context.deviceIdDataStore.edit { preferences ->
                    preferences[DEVICE_ID_KEY] = newId
                }
                cachedDeviceId = newId
                newId
            }
        }
    }
}
