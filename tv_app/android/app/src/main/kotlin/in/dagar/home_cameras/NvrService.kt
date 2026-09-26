package `in`.dagar.home_cameras

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class NvrService : Service() {
    companion object {
        var instance: NvrService? = null
        var config: Map<String, Any?>? = null
        var snapshot: Map<String, Any?> = mapOf("running" to false)
    }

    private var engine: FlutterEngine? = null
    private var bridge: NvrBridge? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var stopping = false
    private var stopResult: MethodChannel.Result? = null
    var ready = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel("nvr", "Camera recorder", NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, NvrService::class.java).setAction("STOP"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "nvr") else Notification.Builder(this)
        val notification = builder.setContentTitle("Home Cameras NVR")
            .setContentText("Local recording / detection enabled. Open the app for camera status.")
            .setSmallIcon(R.drawable.app_icon).setContentIntent(open).setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Stop NVR", stop).build()).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(2201, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(2201, notification)
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "home-cameras:nvr").apply {
            setReferenceCounted(false)
            acquire()
        }
        snapshot = mapOf("running" to true, "message" to "Starting recorder", "cameras" to emptyList<Any>())
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(this)
        loader.ensureInitializationComplete(this, null)
        engine = FlutterEngine(this).also {
            bridge = NvrBridge(this, it)
            it.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "package:home_cameras/main.dart", "nvrMain"))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            getSharedPreferences("nvr", MODE_PRIVATE).edit().putBoolean("stopped", true).apply()
            stopRecorder()
        } else if (ready) configure()
        return START_NOT_STICKY
    }

    fun configure() {
        if (stopping) return
        bridge?.channel?.invokeMethod("configure", config, object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun notImplemented() = failed()
            override fun error(code: String, message: String?, details: Any?) = failed()
            private fun failed() {
                snapshot = mapOf("running" to true, "message" to "Recorder configuration failed. Turn NVR off and retry.")
            }
        })
    }

    fun manual(id: String, result: MethodChannel.Result) {
        if (!ready || stopping) result.error("BUSY", "Recorder is not ready.", null)
        else bridge?.channel?.invokeMethod("manual", id, result)
    }

    fun stopRecorder(result: MethodChannel.Result? = null) {
        if (stopping) {
            result?.error("BUSY", "Recorder is stopping.", null)
            return
        }
        stopping = true
        bridge?.cancelRecorders()
        stopResult = result
        var finished = false
        val complete = {
            if (!finished) {
                finished = true
                bridge?.finishRecorders {
                    snapshot = mapOf("running" to false)
                    stopSelf()
                }
            }
        }
        if (ready) {
            bridge?.channel?.invokeMethod("stop", null, object : MethodChannel.Result {
                override fun success(result: Any?) { complete() }
                override fun notImplemented() { complete() }
                override fun error(code: String, message: String?, details: Any?) { complete() }
            })
        } else complete()
    }

    override fun onDestroy() {
        instance = null
        config = null
        snapshot = mapOf("running" to false)
        bridge?.close()
        engine?.destroy()
        engine = null
        if (wakeLock?.isHeld == true) wakeLock?.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopResult?.success(null)
        stopResult = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
