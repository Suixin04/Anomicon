package com.suixin.anomicon.terminal

import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.MockResponse
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.IOException

class RaisaProtocolTest {
    private val draft = TicketDraft("terminal_bug", "书架未恢复", "保存之后再次打开书架。", "", false,
        JSONObject().put("appVersionLabel", "1.0").put("articleId", "private-entry"),
        listOf(Attachment("log.txt", "text/plain", "test".toByteArray())))

    @Test fun submitAndRetryAgainstLocalRelay() {
        MockWebServer().use { server ->
            for (duplicate in listOf(false, true)) {
                val response = JSONObject().put("issueNumber", 19).put("ticketCode", "RAISA-19")
                    .put("deduplicated", duplicate).put("createdAt", "2026-01-02T03:04:05Z")
                server.enqueue(MockResponse().setResponseCode(201).setBody(response.toString()))
            }
            val relay = RaisaRelay(server.url("/v1/raisa/tickets").toUrl())
            val first = relay.submit(draft, "same-key")
            assertEquals(first, Receipt.stored(first.json()))
            assertEquals("$ISSUES/19", first.issueUrl)
            assertTrue(relay.submit(draft, "same-key").deduplicated)
            val requests = List(2) { server.takeRequest() }
            assertEquals(listOf("same-key", "same-key"), requests.map { it.getHeader("X-Idempotency-Key") })
            assertEquals("POST", requests.first().method)
            assertEquals("/v1/raisa/tickets", requests.first().path)
            val posted = JSONObject(requests.first().body.readUtf8())
            assertFalse(posted.has("diagnostics"))
            assertEquals("dGVzdA==", posted.getJSONArray("attachments").getJSONObject(0).getString("base64Data"))
            assertEquals("private-entry", draft.copy(includeDiagnostics = true).payload().getJSONObject("diagnostics").getString("articleId"))
        }
    }

    @Test fun rateLimitMessageAndSizeLimits() {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setResponseCode(429).setBody(JSONObject().put("message", "稍后重试").toString()))
            val relay = RaisaRelay(server.url("/v1/raisa/tickets").toUrl())
            assertTrue(assertThrows(IOException::class.java) { relay.submit(draft, "mock") }.message!!.contains("稍后重试"))
            val file = Attachment("image.png", "image/png", ByteArray(MAX_FILE))
            assertNull(draft.copy(attachments = listOf(file)).validationError())
            assertNotNull(draft.copy(attachments = List(3) { file }).validationError())
        }
    }
}
