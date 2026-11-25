package com.suixin.anomicon.feature.web

/** Uptime measures elapsed time. A wall-clock anchor dates each persisted interval. */
internal class ReadingClock(private val emit: (Long, Long) -> Unit) {
    private var cursor: Long? = null
    private var anchor = 0L
    private var deadline = 0L

    fun resume(now: Long, wall: Long) {
        cursor = now
        anchor = wall - now
        deadline = now + 90_000
    }

    fun checkpoint(now: Long) {
        val start = cursor ?: return
        val end = minOf(now, deadline)
        if (end > start) {
            cursor = end
            emit(anchor + start, end - start)
        }
    }

    fun interact(now: Long) {
        val start = cursor ?: return
        if (now > deadline) {
            checkpoint(deadline)
            cursor = now
        }
        deadline = now + 90_000
    }

    fun pause(now: Long) {
        checkpoint(now)
        cursor = null
    }
}
