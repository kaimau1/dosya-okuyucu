// **Medya/bildirim API taslakları — YALNIZ yerel tür denetimi için.**
//
// `ci/MediaSession.kt` (MediaSession + ön plan servisi) yalnız Android
// çerçevesini kullanıyor, Flutter'a hiç dokunmuyor; bu yüzden `UsbMass.kt`
// gibi burada tür denetiminden geçirilebiliyor. Gerekçe: `ci/*.kt` yalnız
// CI'da derleniyor ve tek satırlık bir tür hatası 13 dakikalık bir APK
// turunu yakıyor (bkz. HAFIZA 2026-09-02, on birinci tur).
//
// Bu dosya APK'ya GİRMEZ ve gerçek SDK'nın yerine geçmez; yalnız kullanılan
// imzaları taşır. Yeni bir API kullanılırsa buraya da eklenmeli.
package android.app

open class Notification {
    open class Builder {
        constructor(context: android.content.Context)
        constructor(context: android.content.Context, channelId: String)

        fun setContentTitle(text: CharSequence?): Builder = this
        fun setContentText(text: CharSequence?): Builder = this
        fun setSubText(text: CharSequence?): Builder = this
        fun setSmallIcon(icon: Int): Builder = this
        fun setLargeIcon(bitmap: android.graphics.Bitmap?): Builder = this
        fun setContentIntent(intent: PendingIntent?): Builder = this
        fun setDeleteIntent(intent: PendingIntent?): Builder = this
        fun setOngoing(ongoing: Boolean): Builder = this
        fun setShowWhen(show: Boolean): Builder = this
        fun setOnlyAlertOnce(once: Boolean): Builder = this
        fun addAction(action: Action): Builder = this
        fun setStyle(style: Style?): Builder = this
        fun build(): Notification = Notification()
    }

    open class Style

    class MediaStyle : Style() {
        fun setShowActionsInCompactView(vararg indices: Int): MediaStyle = this
        fun setMediaSession(token: android.media.session.MediaSession.Token?): MediaStyle = this
    }

    class Action {
        class Builder(icon: Int, title: CharSequence?, intent: PendingIntent?) {
            fun build(): Action = Action()
        }
    }
}

class NotificationChannel(id: String, name: CharSequence, importance: Int) {
    fun setShowBadge(show: Boolean) {}
}

class NotificationManager {
    fun createNotificationChannel(channel: NotificationChannel) {}
    fun notify(id: Int, notification: Notification) {}
    fun cancel(id: Int) {}

    companion object {
        const val IMPORTANCE_LOW = 2
    }
}

open class Service : android.content.Context() {
    open fun onBind(intent: android.content.Intent?): android.os.IBinder? = null
    open fun onStartCommand(
        intent: android.content.Intent?,
        flags: Int,
        startId: Int
    ): Int = START_NOT_STICKY

    open fun onDestroy() {}
    fun startForeground(id: Int, notification: Notification) {}
    fun startForeground(id: Int, notification: Notification, type: Int) {}
    fun stopForeground(flags: Int) {}
    fun stopForeground(removeNotification: Boolean) {}
    fun stopSelf() {}

    companion object {
        const val START_NOT_STICKY = 2
        const val STOP_FOREGROUND_DETACH = 2
    }
}
