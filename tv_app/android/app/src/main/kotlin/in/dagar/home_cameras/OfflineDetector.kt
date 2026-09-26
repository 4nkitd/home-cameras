package `in`.dagar.home_cameras

import android.content.Context
import android.graphics.Bitmap
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder

class OfflineDetector(context: Context) : AutoCloseable {
    private val labels = context.assets.open("detection-labels.txt").bufferedReader().use { it.readLines() }
    private val model = context.assets.open("efficientdet-lite0.tflite").use { it.readBytes() }.let {
        ByteBuffer.allocateDirect(it.size).order(ByteOrder.nativeOrder()).apply { put(it); rewind() }
    }
    private val interpreter = Interpreter(model, Interpreter.Options().setNumThreads(2))
    private val inputSize = interpreter.getInputTensor(0).shape()[1]
    private val input = ByteBuffer.allocateDirect(inputSize * inputSize * 3).order(ByteOrder.nativeOrder())

    fun detect(bitmap: Bitmap): List<Map<String, Any>> {
        val scaled = Bitmap.createScaledBitmap(bitmap, inputSize, inputSize, true)
        try {
            val pixels = IntArray(inputSize * inputSize)
            scaled.getPixels(pixels, 0, inputSize, 0, 0, inputSize, inputSize)
            input.rewind()
            for (pixel in pixels) {
                input.put((pixel shr 16 and 255).toByte())
                input.put((pixel shr 8 and 255).toByte())
                input.put((pixel and 255).toByte())
            }
            input.rewind()
            // The pinned model's Detection_PostProcess has max_detections=25; output shapes are dynamic.
            val count = 25
            val boxes = Array(1) { Array(count) { FloatArray(4) } }
            val classes = Array(1) { FloatArray(count) }
            val scores = Array(1) { FloatArray(count) }
            val found = FloatArray(1)
            interpreter.runForMultipleInputsOutputs(arrayOf(input), mapOf(0 to boxes, 1 to classes, 2 to scores, 3 to found))
            return (0 until found[0].toInt().coerceIn(0, count)).filter { scores[0][it] >= 0.55f }.mapNotNull {
                val label = labels.getOrNull(classes[0][it].toInt()) ?: return@mapNotNull null
                mapOf("label" to label, "score" to scores[0][it].toDouble())
            }
        } finally { if (scaled !== bitmap) scaled.recycle() }
    }

    override fun close() = interpreter.close()
}
