// Android çerçevesinin geri kalanı — bkz. `android_stubs.kt` başlığı.
package android.content

open class Intent(action: String? = null) {
    constructor(context: Context, target: Class<*>) : this(null)

    var action: String? = action
    fun putExtra(name: String, value: String?): Intent = this
    fun getStringExtra(name: String): String? = null
    fun setPackage(name: String?): Intent = this
    fun addFlags(flags: Int): Intent = this
    fun getBooleanExtra(name: String, default: Boolean): Boolean = default

    companion object {
        const val ACTION_OPEN_DOCUMENT_TREE = "android.intent.action.OPEN_DOCUMENT_TREE"
        const val ACTION_MAIN = "android.intent.action.MAIN"
        const val FLAG_ACTIVITY_NEW_TASK = 268435456
        const val FLAG_GRANT_READ_URI_PERMISSION = 1
        const val FLAG_GRANT_WRITE_URI_PERMISSION = 2
        const val FLAG_GRANT_PERSISTABLE_URI_PERMISSION = 64
    }
}

class IntentFilter(action: String? = null)

abstract class BroadcastReceiver {
    abstract fun onReceive(context: Context, intent: Intent)
}

open class Context {
    val packageName: String = "com.dosyaokuyucu.dosya_okuyucu"
    val applicationContext: Context = this
    val applicationInfo: android.content.pm.ApplicationInfo =
        android.content.pm.ApplicationInfo()
    val packageManager: android.content.pm.PackageManager =
        android.content.pm.PackageManager()

    fun getSystemService(name: String): Any? = null
    fun startService(intent: Intent): Any? = null
    fun startForegroundService(intent: Intent): Any? = null
    fun stopService(intent: Intent): Boolean = true
    fun registerReceiver(
        receiver: BroadcastReceiver,
        filter: IntentFilter,
        flags: Int = 0
    ): Intent? = null

    fun unregisterReceiver(receiver: BroadcastReceiver) {}

    companion object {
        const val USB_SERVICE = "usb"
        const val NOTIFICATION_SERVICE = "notification"
        const val STORAGE_SERVICE = "storage"
        const val RECEIVER_NOT_EXPORTED = 4
    }
}
