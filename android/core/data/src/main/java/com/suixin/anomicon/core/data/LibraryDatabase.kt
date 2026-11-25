package com.suixin.anomicon.core.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

/** Preserves the stable content ID, original ordering and all type-specific payload fields. */
@Entity(primaryKeys = ["collection", "id"])
data class LibraryItem(val collection: String, val id: String, val ordinal: Int, val payload: String)

@Entity
data class OfflineArticle(@PrimaryKey val id: String, val title: String, val kind: String, val savedAt: Long, val htmlPath: String)

@Entity(primaryKeys = ["articleId", "url"], foreignKeys = [ForeignKey(entity = OfflineArticle::class,
    parentColumns = ["id"], childColumns = ["articleId"], onDelete = ForeignKey.CASCADE)])
data class OfflineImage(val articleId: String, val url: String, val path: String)

@Entity
data class CacheFile(@PrimaryKey val name: String, val fetchedAt: Long, val bytes: Long)

@Dao
interface LibraryDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun putItems(items: List<LibraryItem>)
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun putArticle(article: OfflineArticle)
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun putImages(images: List<OfflineImage>)
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun putCache(entries: List<CacheFile>)
    @Query("SELECT * FROM LibraryItem WHERE collection = :collection ORDER BY ordinal")
    fun items(collection: String): Flow<List<LibraryItem>>
    @Query("SELECT * FROM OfflineArticle ORDER BY savedAt DESC") fun shelf(): Flow<List<OfflineArticle>>
    @Query("SELECT * FROM OfflineImage WHERE articleId = :id") suspend fun images(id: String): List<OfflineImage>
    @Query("SELECT * FROM CacheFile WHERE name = :name") suspend fun cache(name: String): CacheFile?
}

@Database(entities = [LibraryItem::class, OfflineArticle::class, OfflineImage::class, CacheFile::class], version = 1)
internal abstract class LibraryDatabase : RoomDatabase() { abstract fun library(): LibraryDao }
