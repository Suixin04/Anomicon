package com.suixin.anomicon.archive3d

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class VerifiedModelTest {
    private val asset = File("src/main/assets/models/scp-173.glb")

    @Test fun bundledModelIsReadyForFilament() {
        val data = verifiedModel(asset.readBytes())
        assertEquals(0, data.position())
        assertEquals(3969944, data.remaining())
    }

    @Test fun changedPayloadIsRejectedBeforeRendering() {
        val data = asset.readBytes()
        data[data.lastIndex] = data.last().inc()
        assertThrows(IllegalArgumentException::class.java) { verifiedModel(data) }
    }
}
