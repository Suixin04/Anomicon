package com.suixin.anomicon.feature.web

import android.os.SystemClock
import androidx.compose.runtime.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.suixin.anomicon.core.data.NativeData
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.math.roundToInt

internal data class ReaderPosition(val offset: Int = 0, val progress: Float = 0f) {
    fun restore(range: Int, density: Float): Int = if (progress > 0) (range * progress).roundToInt()
        else (offset * density).roundToInt().coerceAtMost(range)

    companion object {
        fun at(y: Int, range: Int, density: Float): ReaderPosition = ReaderPosition(
            (y / density).roundToInt(), if (range > 0) (y.toFloat() / range).coerceIn(0f, 1f) else 0f)
    }
}

// Writes outlive the composition. A reopened entry waits for its preceding final write.
private val persistenceScope = CoroutineScope(Dispatchers.Main.immediate + SupervisorJob())
private val order = Mutex()
private fun persist(action: suspend () -> Unit) { persistenceScope.launch { order.withLock { action() } } }

internal class ReaderSession(val id: String, val data: NativeData, initial: ReaderPosition) {
    var position by mutableStateOf(initial)
        private set
    var title = id
    private var dirty = false
    private var settle: Job? = null
    val clock = ReadingClock { start, duration -> persist { data.recordActivity(id, start, duration) } }

    fun visit() { dirty = true; flush() }
    fun interact() { clock.interact(SystemClock.elapsedRealtime()) }
    fun move(value: ReaderPosition) {
        if (position == value) return
        position = value
        dirty = true
        settle?.cancel()
        settle = persistenceScope.launch { delay(350); flush() }
    }
    fun flush() {
        settle?.cancel()
        if (!dirty) return
        dirty = false
        val saved = position
        val name = title
        persist { data.saveReading(id, name, saved.offset, saved.progress) }
    }
    fun favorite(value: Boolean) { persist { data.setFavorite(id, title, value) } }
}

@Composable
internal fun rememberReaderSession(id: String, data: NativeData): ReaderSession? {
    val session by produceState<ReaderSession?>(null, id, data) {
        val row = order.withLock { data.history.first().firstOrNull { it.id == id } }
        value = ReaderSession(id, data, row?.let { ReaderPosition(it.offset, it.progress) } ?: ReaderPosition())
    }
    return session
}

@Composable
internal fun TrackReading(session: ReaderSession) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(session, lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            session.visit()
            session.clock.resume(SystemClock.elapsedRealtime(), System.currentTimeMillis())
            try {
                while (true) { delay(30_000); session.clock.checkpoint(SystemClock.elapsedRealtime()) }
            } finally {
                session.clock.pause(SystemClock.elapsedRealtime())
                session.flush()
            }
        }
    }
}
