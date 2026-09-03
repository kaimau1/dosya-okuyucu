// Android çerçevesinin geri kalanı — bkz. `android_stubs.kt` başlığı.
package android.app

class PendingIntent {
    companion object {
        const val FLAG_MUTABLE = 33554432
        const val FLAG_IMMUTABLE = 67108864
        const val FLAG_UPDATE_CURRENT = 134217728

        fun getService(
            context: android.content.Context,
            requestCode: Int,
            intent: android.content.Intent,
            flags: Int
        ): PendingIntent = PendingIntent()

        fun getActivity(
            context: android.content.Context,
            requestCode: Int,
            intent: android.content.Intent,
            flags: Int
        ): PendingIntent = PendingIntent()

        fun getBroadcast(
            context: android.content.Context,
            requestCode: Int,
            intent: android.content.Intent,
            flags: Int
        ): PendingIntent = PendingIntent()
    }
}
