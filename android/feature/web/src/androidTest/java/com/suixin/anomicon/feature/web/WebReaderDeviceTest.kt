package com.suixin.anomicon.feature.web

import android.os.Bundle
import android.os.SystemClock
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebViewClient
import android.webkit.WebView
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import android.graphics.Rect
import android.os.ParcelFileDescriptor
import android.view.accessibility.AccessibilityNodeInfo
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

class ReaderTestActivity : ComponentActivity() {
    lateinit var page: WebView
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                ReaderContent("scp-002", { finish() }, Modifier.safeDrawingPadding()) { view, url ->
                    page = view
                    val body = """<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
                        <body><main id="page-content"><a id="anchor" href="#overview">本页章节</a>
                        <h2 id="overview">概要</h2><a id="link" href="/scp-003">打开生物母版</a>
                        <table style="width:1700px;height:110px"><tr><td>实验记录</td><td>档案结论</td></tr></table>
                        </main></body></html>"""
                    val delegate = view.webViewClient
                    view.webViewClient = object : WebViewClient() {
                        override fun shouldInterceptRequest(v: WebView, request: WebResourceRequest): WebResourceResponse? =
                            if (request.url.toString() == url) WebResourceResponse("text/html", "UTF-8", body.byteInputStream()) else null
                        override fun shouldOverrideUrlLoading(v: WebView, request: WebResourceRequest) =
                            delegate.shouldOverrideUrlLoading(v, request)
                        override fun onPageFinished(v: WebView, u: String) = delegate.onPageFinished(v, u)
                    }
                    view.loadUrl(url)
                }
            }
        }
    }
}

@RunWith(AndroidJUnit4::class)
class WebReaderDeviceTest {
    private val automation = InstrumentationRegistry.getInstrumentation().uiAutomation

    private fun shell(command: String) {
        ParcelFileDescriptor.AutoCloseInputStream(automation.executeShellCommand(command)).use { it.readBytes() }
    }

    private fun node(text: String): AccessibilityNodeInfo {
        val deadline = SystemClock.elapsedRealtime() + 10000
        while (SystemClock.elapsedRealtime() < deadline) {
            fun match(item: AccessibilityNodeInfo): AccessibilityNodeInfo? {
                if (item.isVisibleToUser && (item.text?.contains(text) == true || item.contentDescription?.contains(text) == true)) return item
                for (i in 0 until item.childCount) item.getChild(i)?.let { match(it) }?.let { return it }
                return null
            }
            val found = automation.rootInActiveWindow?.let(::match)
            if (found != null) return found
            SystemClock.sleep(100)
        }
        throw AssertionError("没有在当前窗口找到 $text")
    }

    private fun click(text: String) {
        val rect = Rect()
        node(text).getBoundsInScreen(rect)
        shell("input tap ${rect.centerX()} ${rect.centerY()}")
    }

    @Test fun realTouchesScrollTableFollowAnchorOpenNativeAndReturn() {
        ActivityScenario.launch(ReaderTestActivity::class.java).use { scenario ->
            click("原版网页")
            node("打开生物母版")
            fun js(code: String): String {
                val result = ArrayBlockingQueue<String>(1)
                scenario.onActivity { it.page.evaluateJavascript(code) { value -> result.offer(value) } }
                return requireNotNull(result.poll(4, TimeUnit.SECONDS))
            }
            fun awaitScript(code: String) {
                val deadline = SystemClock.elapsedRealtime() + 5000
                while (SystemClock.elapsedRealtime() < deadline) {
                    if (js(code) == "true") return
                    SystemClock.sleep(80)
                }
                fail(code)
            }
            awaitScript("!!document.querySelector('[data-anomicon-scroll]')")
            val rect = IntArray(2)
            scenario.onActivity { it.page.getLocationOnScreen(rect) }
            val y = rect[1] + js("Math.round(document.querySelector('table').getBoundingClientRect().y * devicePixelRatio + 25 * devicePixelRatio)").toInt()
            var width = 0
            scenario.onActivity { width = it.page.width }
            fun tapLink(id: String) {
                fun coordinate(axis: String, size: String) = js("(function(){var r=document.getElementById('$id').getBoundingClientRect();return Math.round((r.$axis+r.$size/2)*devicePixelRatio)})() ").toInt()
                shell("input tap ${rect[0] + coordinate("x", "width")} ${rect[1] + coordinate("y", "height")}")
            }
            tapLink("anchor")
            awaitScript("location.hash === '#overview'")
            shell("input swipe ${width * 8 / 10} $y ${width / 5} $y 420")
            awaitScript("document.querySelector('[data-anomicon-scroll]').scrollLeft > 0")
            // A tap during kinetic scrolling stops the fling instead of activating a link.
            val scrollOffset = "document.querySelector('[data-anomicon-scroll]').scrollLeft"
            val deadline = SystemClock.elapsedRealtime() + 5000
            do {
                val before = js(scrollOffset)
                SystemClock.sleep(120)
                if (before == js(scrollOffset)) break
            } while (SystemClock.elapsedRealtime() < deadline)
            tapLink("link")
            node("SCP-003")
            node("原版网页")
            // Some emulator images report gestural mode even with SystemUI's navigation bar disabled.
            // The edge-swipe variant is selected explicitly on devices with an active gesture monitor.
            val edgeGesture = InstrumentationRegistry.getArguments().getString("readerBack") == "edge"
            if (edgeGesture) {
                val midY = rect[1] + 300
                shell("input swipe 1 $midY ${width / 2} $midY 320")
            } else shell("input keyevent BACK")
            node("原生视图")
            node("打开生物母版")
        }
    }
}
