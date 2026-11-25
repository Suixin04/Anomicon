package com.suixin.anomicon.core.data

import android.content.Context
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import androidx.room.Room
import androidx.room.withTransaction
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File

enum class ThemeMode { SYSTEM, LIGHT, DARK }
data class AppSettings(val themeMode: ThemeMode = ThemeMode.SYSTEM, val immersiveMaterial: Boolean = true,
    val haptics: Boolean = true, val fontSize: Float = 18f, val lineHeightMultiple: Float = 1.6f)

private val Context.nativePreferences by preferencesDataStore("researcher")
private object Keys {
    val migrated = booleanPreferencesKey("flutter_v1_imported")
    val theme = stringPreferencesKey("themeMode")
    val material = booleanPreferencesKey("immersiveMaterial")
    val haptics = booleanPreferencesKey("haptics")
    val font = floatPreferencesKey("fontSize")
    val lineHeight = floatPreferencesKey("lineHeightMultiple")
    val assessments = stringPreferencesKey("foundation.assessments")
    val client = stringPreferencesKey("raisa.clientId")
    val starter = booleanPreferencesKey("discovery.starterDismissed")
}

class NativeData private constructor(private val context: Context) {
    companion object {
        @Volatile private var instance: NativeData? = null
        fun open(context: Context): NativeData = instance ?: synchronized(this) {
            instance ?: NativeData(context.applicationContext).also { instance = it }
        }
    }
    private val database = Room.databaseBuilder(context, LibraryDatabase::class.java, "library.db").build()
    val library: LibraryDao = database.library()
    private val prefs = context.nativePreferences
    private val lock = Mutex()
    private val documents = File(context.applicationInfo.dataDir, "app_flutter")
    private val offlineRoot = File(context.filesDir, "offline")
    val archiveObjects = File(documents, "archive3d/v1/objects")

    val settings: Flow<AppSettings> = prefs.data.map {
        AppSettings(it[Keys.theme]?.let(ThemeMode::valueOf) ?: ThemeMode.SYSTEM,
            it[Keys.material] ?: true, it[Keys.haptics] ?: true, it[Keys.font] ?: 18f, it[Keys.lineHeight] ?: 1.6f)
    }.distinctUntilChanged()
    val assessments = prefs.data.map { it[Keys.assessments] ?: "{}" }.distinctUntilChanged()
    val feedbackClientId = prefs.data.map { it[Keys.client] }.distinctUntilChanged()
    val starterDismissed = prefs.data.map { it[Keys.starter] ?: false }.distinctUntilChanged()
    suspend fun setThemeMode(value: ThemeMode) { prefs.edit { it[Keys.theme] = value.name } }
    suspend fun setImmersiveMaterial(value: Boolean) { prefs.edit { it[Keys.material] = value } }
    suspend fun setHaptics(value: Boolean) { prefs.edit { it[Keys.haptics] = value } }
    val favorites = readingEntries("favorites")
    val history = readingEntries("history")
    private fun readingEntries(collection: String) = library.items(collection).map { rows -> rows.map(::readEntry) }.flowOn(Dispatchers.Default)

    private suspend fun prepend(collection: String, id: String, payload: String) {
        val ordinal = (library.firstOrdinal(collection) ?: 0) - 1
        library.putItems(listOf(LibraryItem(collection, id, ordinal, payload)))
    }
    suspend fun saveReading(id: String, title: String, offset: Int, progress: Float) = database.withTransaction {
        val row = library.payload("history", id)?.let(::JSONObject) ?: JSONObject()
        prepend("history", id, row.put("id", id).put("title", title).put("webPixelOffset", offset)
            .put("progress", progress.toDouble()).put("lastReadAt", System.currentTimeMillis()).toString())
    }
    suspend fun setFavorite(id: String, title: String, favorite: Boolean) = database.withTransaction {
        if (favorite) prepend("favorites", id, JSONObject().put("id", id).put("title", title).toString())
        else library.remove("favorites", id)
    }
    suspend fun recordActivity(id: String, startedAt: Long, activeMs: Long) {
        val key = java.util.UUID.randomUUID().toString()
        val zone = java.util.TimeZone.getDefault().getOffset(startedAt) / 60000
        val payload = JSONObject().put("id", id).put("startedAt", startedAt).put("endedAt", startedAt + activeMs)
            .put("activeMs", activeMs).put("offsetMinutes", zone)
        library.putItems(listOf(LibraryItem("activitySegments", key, 0, payload.toString())))
    }
    val assessmentResults = assessments.map { raw ->
        val rows = JSONObject(raw)
        rows.keys().asSequence().associateWith { key ->
            val row = rows.getJSONObject(key)
            AssessmentResult(row.getInt("bestScore"), !row.isNull("firstPassedAt"), row.getInt("attempts"))
        }
    }
    suspend fun saveAssessment(examId: String, score: Int, passed: Boolean) {
        prefs.edit { prefs ->
            val rows = JSONObject(prefs[Keys.assessments] ?: "{}")
            val row = rows.optJSONObject(examId) ?: JSONObject()
            val now = System.currentTimeMillis()
            if (passed && row.isNull("firstPassedAt")) row.put("firstPassedAt", now)
            row.put("bestScore", maxOf(score, row.optInt("bestScore"))).put("lastScore", score)
                .put("attempts", row.optInt("attempts") + 1).put("lastAttemptAt", now)
            prefs[Keys.assessments] = rows.put(examId, row).toString()
        }
    }
    val research = combine(library.items("activitySegments"), assessmentResults) { rows, exams ->
        val bonus = assessmentRewards.entries.sumOf { (id, xp) -> if (exams[id]?.passed == true) xp else 0 }
        researchProfile(rows.map(::readSegment), bonus)
    }.flowOn(Dispatchers.Default)
    val seriesProgress = library.items("seriesProgress").map { rows -> rows.map {
        val row = JSONObject(it.payload)
        SeriesProgress(it.id, row.getString("seriesTitle"), row.getString("entryId"), row.getString("entryTitle"))
    } }
    suspend fun saveSeriesProgress(seriesId: String, seriesTitle: String, entryId: String, entryTitle: String) = database.withTransaction {
        prepend("seriesProgress", seriesId, JSONObject().put("seriesTitle", seriesTitle).put("entryId", entryId).put("entryTitle", entryTitle).toString())
    }
    val searchHistory = library.items("discovery.searchHistory").map { rows -> rows.map { it.payload } }
    suspend fun saveSearch(query: String) = database.withTransaction {
        val text = query.trim()
        if (text.isNotEmpty()) {
            prepend("discovery.searchHistory", text, text)
            library.trim("discovery.searchHistory", 10)
        }
    }
    suspend fun clearSearchHistory() = library.trim("discovery.searchHistory", 0)
    suspend fun dismissStarter() { prefs.edit { it[Keys.starter] = true } }

    fun offlineFile(relativePath: String) = File(offlineRoot, relativePath)
    suspend fun cachedFile(logicalKey: String, extension: String): File? {
        val entry = library.cache("${digest(logicalKey)}.$extension") ?: return null
        return File(File(documents, "content-cache"), entry.name).takeIf(File::isFile)
    }

    /** Invoke before exposing writable screens. A crash before the final edit safely replays the same keys. */
    suspend fun migrateIfNeeded(): Unit = lock.withLock {
        if (prefs.data.first()[Keys.migrated] == true) return@withLock
        withContext(Dispatchers.IO) {
            val snapshot = FlutterSnapshot(context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).all, documents)
            val items = snapshot.items()
            val cache = snapshot.cacheIndex()
            val articles = snapshot.offlineFiles().map { importArticle(it, offlineRoot) }
            val oldSettings = snapshot.string("settings")?.let(::JSONObject)
            database.withTransaction {
                library.putItems(items)
                library.putCache(cache)
                for ((article, images) in articles) {
                    library.putArticle(article)
                    library.putImages(images)
                }
            }
            prefs.edit { values ->
                oldSettings?.let {
                    values[Keys.theme] = ThemeMode.valueOf(it.optString("themeMode", "system").uppercase()).name
                    values[Keys.haptics] = it.optBoolean("hapticEnabled", true)
                    values[Keys.material] = it.optBoolean("immersiveMaterialEnabled", true)
                    values[Keys.font] = it.optDouble("fontSize", 18.0).toFloat()
                    values[Keys.lineHeight] = it.optDouble("lineHeightMultiple", 1.6).toFloat()
                }
                snapshot.string("foundation.assessments")?.let { values[Keys.assessments] = it }
                snapshot.string("raisa.clientId")?.let { values[Keys.client] = it }
                snapshot.starterDismissed?.let { values[Keys.starter] = it }
                values[Keys.migrated] = true
            }
        }
        Unit
    }
}
