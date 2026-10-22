package com.paddle.ocr.postprocess

import org.junit.Assert.*
import org.junit.Test

class CTCDecoderTest {
    @Test fun preservedRepeatedDigitsSeparatedByBlankAndTheirPositions() {
        // 11 <0,5: repeated emissions collapse, but a blank separates true repeated 1s.
        val dictionary = listOf("1", " ", "<", "0", ",", "5")
        val emissions = listOf(1, 1, 0, 1, 2, 3, 4, 5, 6, 6)
        val classes = dictionary.size + 1
        val logits = FloatArray(emissions.size * classes)
        emissions.forEachIndexed { t, c -> logits[t * classes + c] = 1f }
        val decoded = CTCDecoder.decode(logits, longArrayOf(1, 10, 7), dictionary).single()
        assertEquals("11 <0,5", decoded.text)
        assertEquals(listOf(0.05f, 0.35f, 0.45f, 0.55f, 0.65f, 0.75f, 0.85f), decoded.characterPositions)
        assertEquals(1f, decoded.confidence, 0f)
    }

    @Test fun rejectedAllBlankAsEmptyText() {
        val decoded = CTCDecoder.decode(floatArrayOf(1f, 0f, 1f, 0f), longArrayOf(1, 2, 2), listOf("0")).single()
        assertEquals("", decoded.text)
        assertTrue(decoded.characterPositions.isEmpty())
        assertEquals(0f, decoded.confidence, 0f)
    }
}
