// Paket/servis bilgisi taslakları — bkz. `media_stubs.kt` başlığı.
package android.content.pm

class ApplicationInfo {
    val icon: Int = 0
}

class PackageManager {
    fun getLaunchIntentForPackage(name: String): android.content.Intent? = null
}

object ServiceInfo {
    const val FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK = 2
}
