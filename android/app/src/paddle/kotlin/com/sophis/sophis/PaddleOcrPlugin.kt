package com.sophis.sophis

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import com.paddle.ocr.EngineConfig
import com.paddle.ocr.PaddleOCR
import com.paddle.ocr.PaddleOCRConfig
import com.paddle.ocr.model.OCRResult
import com.paddle.ocr.util.OpenCVUtils
import com.paddle.ocr.util.BitmapUtils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.runBlocking
import java.util.concurrent.Executors
import java.io.File
import java.util.UUID
import org.opencv.core.Core
import org.opencv.core.Mat
import org.opencv.core.MatOfInt
import org.opencv.core.Rect
import org.opencv.core.Size
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import kotlin.math.roundToInt

/** Opt-in native OCR. No implicit ML Kit fallback: benchmarks must identify the reader used. */
class PaddleOcrPlugin private constructor(context: Context, messenger: BinaryMessenger) : AutoCloseable {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val channel = MethodChannel(messenger, "sophis/paddle_ocr")
    private var engine: PaddleOCR? = null
    private var recognizer: String? = null

    companion object {
        fun register(context: Context, messenger: BinaryMessenger): AutoCloseable =
            PaddleOcrPlugin(context, messenger)
    }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method !in setOf("prepare", "recognize", "prepareTable", "inspectImage")) {
                result.notImplemented()
            } else {
                worker.execute {
                    try {
                        val model = call.argument<String>("recognizer") ?: "v6"
                        require(model == "v6" || model == "latin") { "Unknown Paddle recognizer" }
                        runBlocking {
                            if (engine == null || recognizer != model) {
                                engine?.release()
                                engine = null
                                check(OpenCVUtils.init(appContext)) { "Cannot load OpenCV" }
                                engine = PaddleOCR.create(
                                    appContext,
                                    PaddleOCRConfig(detLimitSideLen = 2048, detLimitType = "max", detMaxSideLimit = 2048),
                                    EngineConfig(numThreads = 4),
                                    "models/det/inference.onnx",
                                    "models/$model/inference.onnx",
                                    "models/$model/inference.yml",
                                )
                                recognizer = model
                            }
                            val value = if (call.method == "prepare") {
                                mapOf("engine" to "paddle", "recognizer" to model)
                            } else if (call.method == "inspectImage") {
                                inspectImage(requireNotNull(call.argument<String>("path")))
                            } else if (call.method == "prepareTable") {
                                prepareTable(
                                    requireNotNull(call.argument<String>("path")),
                                    requireNotNull(call.argument<Number>("left")).toDouble(),
                                    requireNotNull(call.argument<Number>("top")).toDouble(),
                                    requireNotNull(call.argument<Number>("right")).toDouble(),
                                    requireNotNull(call.argument<Number>("bottom")).toDouble(),
                                )
                            } else {
                                val path = requireNotNull(call.argument<String>("path"))
                                val bitmap = uprightBitmap(path)
                                try {
                                    engine!!.recognize(bitmap).results.map(::toLine)
                                } finally {
                                    bitmap.recycle()
                                }
                            }
                            main.post { result.success(value) }
                        }
                    } catch (error: Exception) {
                        main.post { result.error("paddle_failed", error.message, null) }
                    } catch (error: LinkageError) {
                        main.post { result.error("paddle_unavailable", error.message, null) }
                    }
                }
            }
        }
    }

    private fun uprightBitmap(path: String): Bitmap {
        val input = requireNotNull(BitmapFactory.decodeFile(path)) { "Cannot decode image" }
        val exif = ExifInterface(path)
        val matrix = Matrix()
        if (exif.isFlipped) matrix.postScale(-1f, 1f)
        matrix.postRotate(exif.rotationDegrees.toFloat())
        val upright = Bitmap.createBitmap(input, 0, 0, input.width, input.height, matrix, true)
        if (upright !== input) input.recycle()
        return upright
    }

    /** Matches the shared color/gray/inverted variants without Dart JPEG work. */
    private fun prepareTable(path: String, left: Double, top: Double, right: Double, bottom: Double): List<String> {
        val bitmap = uprightBitmap(path)
        val source = try { BitmapUtils.bitmapToBGRMat(bitmap) } finally { bitmap.recycle() }
        val table = Mat()
        val gray = Mat()
        val inverse = Mat()
        val alternate = Mat()
        val quality = MatOfInt(Imgcodecs.IMWRITE_JPEG_QUALITY, 98)
        val directory = File(appContext.cacheDir, "sophis-label-ocr-${UUID.randomUUID()}")
        try {
            val x = left.roundToInt().coerceIn(0, source.cols() - 1)
            val y = top.roundToInt().coerceIn(0, source.rows() - 1)
            val width = right.roundToInt().coerceIn(x + 1, source.cols()) - x
            val height = bottom.roundToInt().coerceIn(y + 1, source.rows()) - y
            val crop = source.submat(Rect(x, y, width, height))
            try {
                Imgproc.resize(crop, table, Size(1800.0, (height * 1800.0 / width).roundToInt().coerceAtLeast(1).toDouble()), 0.0, 0.0, Imgproc.INTER_CUBIC)
                // A second scale helps when interpolation obscures a decimal or a letter.
                Imgproc.resize(crop, alternate, Size(1400.0, (height * 1400.0 / width).roundToInt().coerceAtLeast(1).toDouble()), 0.0, 0.0, Imgproc.INTER_LINEAR)
            } finally {
                crop.release()
            }
            Imgproc.cvtColor(table, gray, Imgproc.COLOR_BGR2GRAY)
            Core.bitwise_not(gray, inverse)
            Imgproc.cvtColor(alternate, alternate, Imgproc.COLOR_BGR2GRAY)
            check(directory.mkdirs()) { "Cannot create table image directory" }
            return listOf(table, gray, inverse, alternate).mapIndexed { index, image ->
                val output = File(directory, "table-$index.jpg")
                check(Imgcodecs.imwrite(output.absolutePath, image, quality)) { "Cannot encode table image" }
                output.absolutePath
            }
        } catch (error: Exception) {
            directory.deleteRecursively()
            throw error
        } finally {
            source.release()
            table.release()
            gray.release()
            inverse.release()
            alternate.release()
            quality.release()
        }
    }

    private fun inspectImage(path: String): List<Double> {
        val bitmap = uprightBitmap(path)
        val source = try { BitmapUtils.bitmapToBGRMat(bitmap) } finally { bitmap.recycle() }
        val sample = Mat()
        val gray = Mat()
        try {
            val width = (source.cols() * 0.9).roundToInt().coerceAtLeast(1)
            val height = (source.rows() * 0.76).roundToInt().coerceAtLeast(1)
            val x = ((source.cols() - width) / 2.0).roundToInt()
            val y = (source.rows() * 0.46 - height / 2.0).roundToInt().coerceIn(0, source.rows() - height)
            val crop = source.submat(Rect(x, y, width, height))
            try {
                Imgproc.resize(crop, sample, Size(240.0, (height * 240.0 / width).roundToInt().coerceAtLeast(1).toDouble()), 0.0, 0.0, Imgproc.INTER_NEAREST)
            } finally { crop.release() }
            Imgproc.cvtColor(sample, gray, Imgproc.COLOR_BGR2GRAY)
            val pixels = ByteArray(gray.rows() * gray.cols())
            gray.get(0, 0, pixels)
            fun luminance(index: Int): Int = pixels[index].toInt() and 255
            var sum = 0.0
            var squares = 0.0
            for (index in pixels.indices) {
                val value = luminance(index).toDouble()
                sum += value
                squares += value * value
            }
            val mean = sum / pixels.size
            var laplacian = 0.0
            var count = 0
            for (row in 1 until gray.rows() - 1) {
                for (column in 1 until gray.cols() - 1) {
                    val index = row * gray.cols() + column
                    laplacian += kotlin.math.abs(4 * luminance(index) - luminance(index - 1) - luminance(index + 1) - luminance(index - gray.cols()) - luminance(index + gray.cols()))
                    count++
                }
            }
            return listOf(source.cols().toDouble(), source.rows().toDouble(), mean, squares / pixels.size - mean * mean, if (count == 0) 0.0 else laplacian / count)
        } finally {
            source.release()
            sample.release()
            gray.release()
        }
    }

    private fun toLine(result: OCRResult): Map<String, Any> {
        val points = result.box.points
        val left = points.minOf { it.x }.toDouble()
        val right = points.maxOf { it.x }.toDouble()
        val top = points.minOf { it.y }.toDouble()
        val bottom = points.maxOf { it.y }.toDouble()
        // Positions come from CTC emission timesteps, not string-length interpolation.
        val tokens = Regex("<\\s*\\d+(?:[.,]\\d+)?|\\d+(?:[.,]\\d+)?|[^\\s\\d<>]+|[<>]")
            .findAll(result.text).map { match ->
                val positions = result.characterPositions
                val fraction = if (positions.size == result.text.length) {
                    (positions[match.range.first] + positions[match.range.last]) / 2.0
                } else 0.5
                val startX = (points[0].x + points[3].x) / 2.0
                val startY = (points[0].y + points[3].y) / 2.0
                val endX = (points[1].x + points[2].x) / 2.0
                val endY = (points[1].y + points[2].y) / 2.0
                mapOf("text" to match.value.replace(Regex("^<\\s+"), "<"),
                    "centerX" to startX + fraction * (endX - startX),
                    "centerY" to startY + fraction * (endY - startY))
            }.toList()
        return mapOf("text" to result.text, "top" to top, "height" to bottom - top,
            "left" to left, "right" to right, "confidence" to result.confidence.toDouble(), "tokens" to tokens)
    }

    override fun close() {
        channel.setMethodCallHandler(null)
        // Release only after pending inference completes.
        worker.execute { runBlocking { engine?.release(); engine = null } }
        worker.shutdown()
    }
}
