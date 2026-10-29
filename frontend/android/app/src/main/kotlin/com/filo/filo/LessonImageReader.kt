package com.filo.filo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Bounded, sampled decoding before ML Kit sees a photo. Original files stay untouched. */
class LessonImageReader(private val context: Context) {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    init {
        executor.execute {
            context.cacheDir.listFiles()?.filter {
                it.isFile && it.name.startsWith("lesson-ocr-") && it.name.endsWith(".jpg") &&
                    System.currentTimeMillis() - it.lastModified() > 86_400_000L
            }?.forEach { it.delete() }
        }
    }
    fun close() { executor.shutdown() }

    fun prepare(path: String, result: MethodChannel.Result) {
        executor.execute {
            var bitmap: Bitmap? = null
            try {
                val source = File(path)
                require(source.isFile && source.length() <= 10L * 1024 * 1024)
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, bounds)
                require(bounds.outWidth > 0 && bounds.outHeight > 0)
                var sample = 1
                fun sampled(n: Int) = (n.toLong() + sample - 1) / sample
                while (sampled(bounds.outWidth) > 2048 || sampled(bounds.outHeight) > 2048 ||
                    sampled(bounds.outWidth) * sampled(bounds.outHeight) > 4_000_000L) sample *= 2
                bitmap = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply {
                    inSampleSize = sample
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                }) ?: error("Unreadable image")
                require(bitmap!!.width <= 2048 && bitmap!!.height <= 2048)
                require(bitmap!!.width.toLong() * bitmap!!.height <= 4_000_000L)
                val orientation = ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                val matrix = Matrix()
                when (orientation) {
                    ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
                    ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
                    ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
                    ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
                    ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
                    ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.setRotate(270f); matrix.postScale(-1f, 1f) }
                    ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(270f)
                }
                if (!matrix.isIdentity) {
                    val rotated = Bitmap.createBitmap(bitmap!!, 0, 0, bitmap!!.width, bitmap!!.height, matrix, true)
                    if (rotated !== bitmap) { bitmap!!.recycle(); bitmap = rotated }
                }
                // NV21 avoids another bitmap decode on ML Kit's platform-channel thread.
                val width = bitmap!!.width and -2
                val height = bitmap!!.height and -2
                if (width < 2 || height < 2) {
                    main.post { result.error("NO_TEXT", "No readable text found in this file.", null) }
                    return@execute
                }
                val rgb = IntArray(width * height)
                bitmap!!.getPixels(rgb, 0, width, 0, 0, width, height)
                val nv21 = lessonNv21(rgb, width, height)
                val payload = mapOf("bytes" to nv21, "width" to width, "height" to height,
                    "resized" to (sample > 1), "cropped" to (width != bitmap!!.width || height != bitmap!!.height))
                main.post { result.success(payload) }
            } catch (_: Throwable) {
                main.post { result.error("READ_FAILED", "The image could not be read.", null) }
            } finally { bitmap?.recycle() }
        }
    }
}

internal fun lessonNv21(rgb: IntArray, width: Int, height: Int): ByteArray {
    require(width in 2..2048 && height in 2..2048 && width % 2 == 0 && height % 2 == 0)
    require(width.toLong() * height <= 4_000_000L && rgb.size == width * height)
    val output = ByteArray(width * height * 3 / 2)
    var uv = width * height
    for (y in 0 until height) for (x in 0 until width) {
        val color = rgb[y * width + x]
        val a = (color ushr 24) and 255
        fun overWhite(c: Int) = (c * a + 255 * (255 - a) + 127) / 255
        val r = overWhite((color shr 16) and 255)
        val g = overWhite((color shr 8) and 255)
        val b = overWhite(color and 255)
        output[y * width + x] = ((((66*r + 129*g + 25*b + 128) shr 8) + 16).coerceIn(0, 255)).toByte()
        if (y % 2 == 0 && x % 2 == 0) {
            output[uv++] = ((((112*r - 94*g - 18*b + 128) shr 8) + 128).coerceIn(0, 255)).toByte()
            output[uv++] = ((((-38*r - 74*g + 112*b + 128) shr 8) + 128).coerceIn(0, 255)).toByte()
        }
    }
    return output
}
