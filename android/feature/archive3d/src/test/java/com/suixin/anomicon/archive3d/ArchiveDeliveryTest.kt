package com.suixin.anomicon.archive3d

import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class ArchiveDeliveryTest {
    @get:Rule val temporary = TemporaryFolder()
    private val source = resolveAsset("scp-173")!!
    private val bytes = File("src/main/assets", source.resourcePath).readBytes()
    private val remote = source.copy(resourcePath = "", downloadUrl = "https://example.test/model.glb")

    @Test fun catalogMatchesBundledContent() {
        assertEquals(10, archiveAssets.size)
        assertEquals(4, archiveAssets.count { it.bundled })
        archiveAssets.filter { it.bundled }.forEach { verify(it, ByteBuffer.wrap(File("src/main/assets", it.resourcePath).readBytes())) }
        assertTrue(hasArchiveModel(" /SCP-049 "))
        assertFalse(hasArchiveModel("scp-999"))
    }

    private fun store(reply: (Request) -> Response): ArchiveStore = ArchiveStore(temporary.root,
        OkHttpClient.Builder().addInterceptor { reply(it.request()) }.build())
    private fun response(r: Request, code: Int, data: ByteArray, range: String? = null) = Response.Builder()
        .request(r).protocol(Protocol.HTTP_1_1).code(code).message("Test model").body(data.toResponseBody())
        .apply { if (range != null) header("Content-Range", range) }.build()

    @Test fun pauseAndResumeAcrossStoreInstances() = runBlocking {
        val first = store { response(it, 200, bytes) }
        val task = launch { first.download(remote) { if (it > 130000) cancel() } }
        task.join()
        assertTrue(task.isCancelled)
        val offset = first.partial(remote).length().toInt()
        assertTrue(offset in 1 until bytes.size)
        assertFalse(first.ready(remote))
        val resumed = store { r ->
            assertEquals("bytes=$offset-", r.header("Range"))
            response(r, 206, bytes.copyOfRange(offset, bytes.size), "bytes $offset-${bytes.lastIndex}/${bytes.size}")
        }
        resumed.download(remote) {}
        assertTrue(resumed.ready(remote))
        assertFalse(resumed.partial(remote).exists())
        assertArrayEquals(bytes, resumed.installed(remote).readBytes())
    }

    @Test fun wholeResponseReplacesPartialAndCorruptionCannotInstall() = runBlocking {
        val store = store { response(it, 200, bytes) }
        store.partial(remote).writeBytes(bytes.copyOf(64))
        store.download(remote) {}
        assertArrayEquals(bytes, store.installed(remote).readBytes())
        val bad = remote.copy(assetId = "bad-model", sha256 = "0".repeat(64))
        try { store.download(bad) {}; fail("坏模型不应安装") } catch (_: IOException) { }
        assertFalse(store.ready(bad))
        assertFalse(store.partial(bad).exists())
    }
}
