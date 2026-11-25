package com.suixin.anomicon.core.data

import org.json.JSONObject
import java.time.LocalDate
import java.util.TimeZone

const val MINUTE_MS = 60_000L
private const val DAY_MS = 86_400_000L
internal val assessmentRewards = mapOf("cert-01" to 15, "cert-02" to 20, "cert-03" to 25)
data class ReadingEntry(val id: String, val title: String, val offset: Int, val progress: Float, val completed: Boolean = false)
data class SeriesProgress(val seriesId: String, val seriesTitle: String, val entryId: String, val entryTitle: String)
data class AssessmentResult(val score: Int, val passed: Boolean, val attempts: Int)

internal fun readEntry(item: LibraryItem): ReadingEntry {
    val row = JSONObject(item.payload)
    val blocks = row.optInt("blockCount")
    val progress = when {
        row.has("progress") -> row.getDouble("progress").toFloat()
        row.optBoolean("completed") -> 1f
        blocks > 1 -> row.optInt("scrollOffset").toFloat() / (blocks - 1)
        else -> 0f
    }
    return ReadingEntry(item.id, row.optString("title", item.id), row.optInt("webPixelOffset"), progress.coerceIn(0f, 1f), row.optBoolean("completed"))
}

internal data class Activity(val id: String, val start: Long, val end: Long, val ms: Long, val zoneMinutes: Int)
internal fun readSegment(item: LibraryItem): Activity {
    val row = JSONObject(item.payload)
    val start = row.getLong("startedAt")
    return Activity(row.getString("id"), start, row.getLong("endedAt"), row.getLong("activeMs"),
        row.optInt("offsetMinutes", TimeZone.getDefault().getOffset(start) / 60000))
}

data class ResearchProfile(val daily: Map<LocalDate, Long> = emptyMap(), val researched: Int = 0, val bonus: Int = 0) {
    val totalMs = daily.values.sum()
    val xp = totalMs / MINUTE_MS + researched * 8 + bonus
    private fun threshold(level: Int) = 8 * (level - 1) * (level - 1)
    val level = (1..50).last { threshold(it) <= xp }
    val earned = xp - threshold(level)
    val target = if (level == 50) 0 else threshold(level + 1) - threshold(level)
    val rank = when (level) {
        50 -> "首席档案编审"
        in 35..49 -> "档案编审"
        in 20..34 -> "高级档案员"
        in 10..19 -> "档案员"
        in 5..9 -> "档案助理"
        else -> "见习档案员"
    }
}

internal fun researchProfile(segments: List<Activity>, bonus: Int): ResearchProfile {
    val days = mutableMapOf<LocalDate, Long>()
    val titles = mutableMapOf<String, Long>()
    for (segment in segments.sortedBy { it.start }) {
        val zone = segment.zoneMinutes * MINUTE_MS
        var cursor = segment.start
        var remaining = segment.ms
        do {
            val day = Math.floorDiv(cursor + zone, DAY_MS)
            val date = LocalDate.ofEpochDay(day)
            val end = minOf(segment.end, (day + 1) * DAY_MS - zone)
            val slice = if (end == segment.end) remaining else
                (segment.ms * ((end - cursor).toDouble() / (segment.end - segment.start))).toLong()
            val used = days.getOrDefault(date, 0L)
            val credited = minOf(slice, 180 * MINUTE_MS - used)
            days[date] = used + credited
            titles[segment.id] = titles.getOrDefault(segment.id, 0L) + credited
            remaining -= slice
            cursor = end
        } while (cursor < segment.end)
    }
    return ResearchProfile(days, titles.values.count { it >= MINUTE_MS }, bonus)
}
