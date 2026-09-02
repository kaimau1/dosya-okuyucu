// Android çerçevesinin geri kalanı — bkz. `android_stubs.kt` başlığı.
package android.content

open class Intent(action: String? = null) {
    var action: String? = action
    fun setPackage(name: String?): Intent = this
    fun addFlags(flags: Int): Intent = this
    fun getBooleanExtra(name: String, default: Boolean): Boolean = default

    companion object {
        const val ACTION_OPEN_DOCUMENT_TREE = "android.intent.action.OPEN_DOCUMENT_TREE"
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
    fun getSystemService(name: String): Any? = null
    fun registerReceiver(
        receiver: BroadcastReceiver,
        filter: IntentFilter,
        flags: Int = 0
    ): Intent? = null

    fun unregisterReceiver(receiver: BroadcastReceiver) {}

    companion object {
        const val USB_SERVICE = "usb"
        const val STORAGE_SERVICE = "storage"
        const val RECEIVER_NOT_EXPORTED = 4
    }
}
