// Android çerçevesinin geri kalanı — bkz. `android_stubs.kt` başlığı.
package android.app

class PendingIntent {
    companion object {
        const val FLAG_MUTABLE = 33554432

        fun getBroadcast(
            context: android.content.Context,
            requestCode: Int,
            intent: android.content.Intent,
            flags: Int
        ): PendingIntent = PendingIntent()
    }
}
