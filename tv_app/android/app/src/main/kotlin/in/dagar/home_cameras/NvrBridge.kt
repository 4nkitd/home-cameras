package `in`.dagar.home_cameras

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors

class NvrBridge(private val context: Context, engine: FlutterEngine, private val activity: Activity? = null) {
    val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "in.dagar.home_cameras/nvr")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var detector: OfflineDetector? = null
    private var exportResult: MethodChannel.Result? = null
    private var exportStream: FileInputStream? = null
    private val recorders = mutableMapOf<String, Long>()
    @Volatile private var closing = false
    private val native by lazy { NativeRecorder() }

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "paths" -> {
                        val root = File(context.filesDir, "recordings").apply { mkdirs() }
                        result.success(mapOf("root" to root.path, "freeBytes" to root.usableSpace))
                    }
                    "status" -> result.success(NvrService.snapshot + mapOf("stopped" to context.getSharedPreferences("nvr", Context.MODE_PRIVATE).getBoolean("stopped", false)))
                    "start" -> {
                        if (activity == null) throw IllegalStateException()
                        @Suppress("UNCHECKED_CAST")
                        val config = call.arguments as Map<String, Any?>
                        NvrService.config = config
                        context.getSharedPreferences("nvr", Context.MODE_PRIVATE).edit().putBoolean("stopped", false).apply()
                        if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission("android.permission.POST_NOTIFICATIONS") != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                            activity.requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 7302)
                        }
                        val intent = Intent(context, NvrService::class.java)
                        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
                        result.success(null)
                    }
                    "stop" -> {
                        if (NvrService.instance == null) result.success(null)
                        else NvrService.instance?.stopRecorder(result)
                    }
                    "manual" -> {
                        val service = NvrService.instance
                        if (service == null) result.error("OFF", "Enable NVR first.", null)
                        else service.manual(call.arguments as String, result)
                    }
                    "ready" -> {
                        NvrService.instance?.ready = true
                        result.success(null)
                        NvrService.instance?.configure()
                    }
                    "publish" -> {
                        @Suppress("UNCHECKED_CAST")
                        val state = call.arguments as Map<String, Any?>
                        NvrService.snapshot = state + mapOf("running" to true)
                        result.success(null)
                    }
                    "detect" -> {
                        val bytes = call.arguments as ByteArray
                        executor.execute {
                            try {
                                val image = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: throw IllegalArgumentException()
                                try {
                                    val model = detector ?: OfflineDetector(context).also { detector = it }
                                    val found = model.detect(image)
                                    main.post { result.success(found) }
                                } finally { image.recycle() }
                            } catch (_: Exception) {
                                main.post { result.error("DETECT", "Offline detector could not process this frame.", null) }
                            }
                        }
                    }
                    "recordStart", "recordStop", "recordStatus" -> {
                        if (activity != null) throw IllegalStateException()
                        val args = call.arguments as Map<*, *>
                        val id = args["id"] as String
                        executor.execute {
                            try {
                                when (call.method) {
                                    "recordStart" -> {
                                        val root = File(context.filesDir, "recordings").canonicalFile
                                        val file = File(args["path"] as String).canonicalFile
                                        require(file.parentFile == root && file.extension == "mkv")
                                        val url = args["url"] as String
                                        require(android.net.Uri.parse(url).scheme == "rtsp")
                                        synchronized(recorders) { recorders.remove(id) }?.let { native.stop(it) }
                                        synchronized(recorders) {
                                            check(!closing)
                                            recorders[id] = native.start(url, file.path)
                                        }
                                        main.post { result.success(null) }
                                    }
                                    "recordStop" -> {
                                        synchronized(recorders) { recorders.remove(id) }?.let { native.stop(it) }
                                        main.post { result.success(null) }
                                    }
                                    else -> {
                                        val state = synchronized(recorders) { recorders[id]?.let { native.status(it) } ?: -1 }
                                        main.post { result.success(state) }
                                    }
                                }
                            } catch (_: Exception) {
                                main.post { result.error("RECORD", "Recording needs an H.264 or H.265 RTSP stream and writable storage.", null) }
                            }
                        }
                    }
                    "export" -> {
                        if (activity == null || exportResult != null) throw IllegalStateException()
                        val root = File(context.filesDir, "recordings").canonicalFile
                        val file = File(root, call.arguments as String).canonicalFile
                        require(file.parentFile == root && file.extension == "mkv" && file.isFile)
                        exportStream = file.inputStream()
                        exportResult = result
                        try {
                            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "video/x-matroska"
                                putExtra(Intent.EXTRA_TITLE, file.name)
                            }, 7303)
                        } catch (e: Exception) {
                            exportResult = null
                            exportStream?.close()
                            exportStream = null
                            throw e
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("NVR", "This recorder operation is unavailable. Check storage and try again.", null)
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 7303) return false
        val result = exportResult ?: return true
        val input = exportStream
        exportResult = null
        exportStream = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || input == null) {
            input?.close()
            result.success(false)
            return true
        }
        executor.execute {
            try {
                input.use { source ->
                    context.contentResolver.openOutputStream(uri)?.use { output -> source.copyTo(output) } ?: throw IllegalStateException()
                }
                main.post { result.success(true) }
            } catch (_: Exception) {
                main.post { result.error("EXPORT", "Could not export recording. Check destination storage.", null) }
            }
        }
        return true
    }

    fun close() {
        cancelRecorders()
        channel.setMethodCallHandler(null)
        exportResult?.success(false)
        exportResult = null
        exportStream?.close()
        exportStream = null
        executor.execute {
            val remaining = synchronized(recorders) { recorders.values.toList().also { recorders.clear() } }
            remaining.forEach { native.stop(it) }
            detector?.close()
            detector = null
        }
        executor.shutdown()
    }

    fun cancelRecorders() {
        closing = true
        synchronized(recorders) { recorders.values.forEach { native.cancel(it) } }
    }

    fun finishRecorders(done: () -> Unit) {
        cancelRecorders()
        executor.execute {
            val remaining = synchronized(recorders) { recorders.values.toList().also { recorders.clear() } }
            remaining.forEach { native.stop(it) }
            main.post { done() }
        }
    }
}
