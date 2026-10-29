package com.filo.filo

import org.junit.Assert.assertArrayEquals
import org.junit.Test

class LessonImageReaderTest {
    @Test fun blackWhiteAndRedHaveExpectedLumaAndVuOrder() {
        fun values(color: Int) = lessonNv21(IntArray(4) { color }, 2, 2).map { it.toInt() and 255 }.toIntArray()
        assertArrayEquals(intArrayOf(16, 16, 16, 16, 128, 128), values(0xff000000.toInt()))
        assertArrayEquals(intArrayOf(235, 235, 235, 235, 128, 128), values(0xffffffff.toInt()))
        assertArrayEquals(intArrayOf(235, 235, 235, 235, 128, 128), values(0x00000000))
        assertArrayEquals(intArrayOf(82, 82, 82, 82, 240, 90), values(0xffff0000.toInt()))
    }
    @Test(expected = IllegalArgumentException::class)
    fun oddDimensionsAreRejectedBeforeConversion() {
        lessonNv21(IntArray(6), 3, 2)
    }
}
