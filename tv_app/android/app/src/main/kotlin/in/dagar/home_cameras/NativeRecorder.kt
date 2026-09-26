package `in`.dagar.home_cameras

class NativeRecorder {
    companion object { init { System.loadLibrary("home_recorder") } }
    external fun start(uri: String, file: String): Long
    external fun status(handle: Long): Int
    external fun cancel(handle: Long)
    external fun stop(handle: Long)
}
