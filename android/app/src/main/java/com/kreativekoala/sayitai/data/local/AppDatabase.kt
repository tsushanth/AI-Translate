package com.kreativekoala.sayitai.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [TranslationEntryEntity::class],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun translationDao(): TranslationDao

    companion object {
        const val DATABASE_NAME = "sayitai_database"
    }
}
