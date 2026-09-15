package `in`.dagar.home_cameras

import android.content.Intent
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var permissionResult: MethodChannel.Result? = null
    private val networkPermission = "android.permission.ACCESS_LOCAL_NETWORK"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "in.dagar.home_cameras/tv")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNetwork" -> {
                        if (Build.VERSION.SDK_INT < 37 || checkSelfPermission(networkPermission) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else if (permissionResult != null) {
                            result.error("BUSY", "A network permission request is already open.", null)
                        } else {
                            permissionResult = result
                            requestPermissions(arrayOf(networkPermission), 7301)
                        }
                    }
                    "acquireDiscovery" -> {
                        try {
                            if (multicastLock == null) {
                                val wifi = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                                multicastLock = wifi.createMulticastLock("home-cameras-discovery").apply { setReferenceCounted(false) }
                            }
                            multicastLock?.acquire()
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("DISCOVERY", "Network discovery is unavailable.", null)
                        }
                    }
                    "releaseDiscovery" -> {
                        if (multicastLock?.isHeld == true) multicastLock?.release()
                        result.success(null)
                    }
                    "setAwake" -> {
                        if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    "openNetworkSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("SETTINGS", "Open network settings from the TV home screen.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7301) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }

    override fun onDestroy() {
        if (multicastLock?.isHeld == true) multicastLock?.release()
        permissionResult?.success(false)
        permissionResult = null
        super.onDestroy()
    }
}
