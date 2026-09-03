package com.dosyaokuyucu.dosya_okuyucu

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder

/**
 * **Gerçek MediaSession** — bildirimdeki sürüklenebilir ilerleme çubuğu,
 * kilit ekranı kontrolleri ve kulaklık düğmeleri.
 *
 * ## Niye native (kullanıcı isteği 2026-09-03)
 * *"MediaSession yapalım sesler için bildirim çubuğunda düzgün çalışması için
 * tam bir premium alan olsun Spotify YouTube Music gibi."*
 *
 * `flutter_local_notifications`ın `MediaStyleInformation`ı yalnız **görünüm**
 * verir: bir oturum (session) tokenı olmadığı için Android'in medya
 * denetleyicisi (bildirim gölgesindeki oynatıcı, kilit ekranı, saat/kulaklık)
 * devreye girmez ve **ilerleme çubuğu çizilmez**. Çubuğu çizen şey
 * `PlaybackState`in konum + hız alanıdır: sistem konumu kendisi ilerletir,
 * kullanıcı sürükleyince `onSeekTo` çağrılır. Bunu ancak bir `MediaSession`
 * verebilir.
 *
 * **Niye `audio_service` paketi DEĞİL:** o paket kendi Activity/Service
 * yaşam döngüsünü dayatıyor (`AudioServiceActivity`den türemek gerekiyor) ve
 * bizde `MainActivity` elle bakımlı; ayrıca çalma motorumuz Dart tarafında
 * (`audioplayers` / `video_player`) ve orada kalmalı. Burada YALNIZ oturum +
 * bildirim var — çerçevenin `android.media.session` API'si (API 21+), ek
 * bağımlılık yok, derleme zinciri oynamıyor (bkz. HAFIZA'daki "tek paket için
 * derleme zincirini oynatma" yasağı).
 *
 * ## Kim neyi yapıyor
 * * **Dart** çalar (ses/video), durumu bilir → `update(...)` ile buraya iter.
 * * **Burası** oturumu, bildirimi ve ön plan servisini yönetir; kullanıcı
 *   dokunuşlarını (`play`, `pause`, `next`, `previous`, `seek`, `stop`)
 *   [onAction] ile Dart'a geri verir.
 *
 * Flutter'a HİÇ bağlı değil: `tool/check_kotlin.sh` bu dosyayı taslaklarla tür
 * denetiminden geçirebilsin diye (bkz. HAFIZA 2026-09-02, on birinci tur).
 */
object MediaBridge {

    /** Bildirim/oturum eylemi Dart'a gider: (eylem, sayısal argüman). */
    var onAction: ((String, Long) -> Unit)? = null

    /** Bildirime DOKUNULDU (düğmeye değil) — uygulamayı açacak yük. */
    var openPayload: String? = null
        private set

    const val CHANNEL_ID = "media_playback"
    const val NOTIFICATION_ID = 91001

    const val ACTION_PLAY = "play"
    const val ACTION_PAUSE = "pause"
    const val ACTION_NEXT = "next"
    const val ACTION_PREVIOUS = "previous"
    const val ACTION_STOP = "stop"
    const val ACTION_SEEK = "seek"

    /** Bildirimdeki düğmelerin servise gönderdiği intent eylemi öneki. */
    const val INTENT_PREFIX = "com.dosyaokuyucu.dosya_okuyucu.media."

    /** Uygulamayı açan intent'e konan yük (MainActivity okur). */
    const val EXTRA_PAYLOAD = "media_payload"

    // ── Dart'tan gelen durum ──────────────────────────────────────────────
    private var title: String = ""
    private var subtitle: String = ""
    private var album: String = ""
    private var durationMs: Long = 0
    private var positionMs: Long = 0
    private var playing: Boolean = false
    private var speed: Float = 1f
    private var hasNext: Boolean = false
    private var hasPrevious: Boolean = false
    private var coverPath: String? = null
    private var payload: String = ""

    /** Bildirim düğmelerinin metinleri — arayüz dilinde, Dart'tan gelir. */
    private var labels: Map<String, String> = emptyMap()
    /** Ses mi video mu — yalnız bildirimin alt yazısında ayrım için. */
    private var isVideo: Boolean = false

    private var session: MediaSession? = null
    private var channelReady = false
    private var serviceStarted = false

    /** Son çizilen bildirimin imzası — aynı içerik iki kez çizilmesin. */
    private var lastSignature: String? = null

    /** Çözülmüş kapak (yol → bitmap); her tazelemede diskten okumak pahalı. */
    private var coverBitmap: Bitmap? = null
    private var coverBitmapPath: String? = null

    /** Oturum ayakta mı (Dart tarafı ve testler için). */
    val active: Boolean
        get() = session != null

    /**
     * Dart'tan gelen durum. Metadata + `PlaybackState` her çağrıda tazelenir
     * (ucuz binder çağrıları), bildirim ise **yalnız görünen bir şey
     * değiştiyse** yeniden çizilir: çalarken saniyede bir bildirim çizmek
     * MIUI'de gölgeyi titretiyor ve pil yakıyor. Konumu sistem zaten
     * `PlaybackState`in hızından kendisi ilerletiyor — çubuğun akması için
     * bildirimi tazelemek GEREKMİYOR.
     */
    fun update(context: Context, args: Map<String, Any?>) {
        title = args["title"] as? String ?: ""
        subtitle = args["subtitle"] as? String ?: ""
        album = args["album"] as? String ?: ""
        durationMs = (args["duration"] as? Number)?.toLong() ?: 0L
        positionMs = (args["position"] as? Number)?.toLong() ?: 0L
        playing = args["playing"] as? Boolean ?: false
        speed = (args["speed"] as? Number)?.toFloat() ?: 1f
        hasNext = args["hasNext"] as? Boolean ?: false
        hasPrevious = args["hasPrevious"] as? Boolean ?: false
        coverPath = args["cover"] as? String
        payload = args["payload"] as? String ?: ""
        isVideo = args["video"] as? Boolean ?: false
        @Suppress("UNCHECKED_CAST")
        labels = (args["labels"] as? Map<String, String>) ?: labels

        val app = context.applicationContext
        ensureChannel(app)
        val session = ensureSession(app)
        session.setMetadata(buildMetadata(app))
        session.setPlaybackState(buildState())
        if (!session.isActive) session.isActive = true

        val signature = listOf(
            title, subtitle, playing, hasNext, hasPrevious,
            coverPath ?: "", durationMs
        ).joinToString("|")
        val changed = signature != lastSignature
        lastSignature = signature

        if (playing) {
            // **Ön plan servisi yalnız ÇALARKEN.** Duraklamış bir oynatıcı
            // için süreci ayakta tutmak pil yakar (aynı karar 2026-09-02'de
            // eski bildirim yolunda da verilmişti).
            startForeground(app, changed)
        } else {
            // Duraklatınca servis bırakılır ama bildirim KALIR: kullanıcı
            // oradan devam edebilsin. `detach` bildirimi servisten koparır,
            // yoksa Android onu servisle birlikte siler.
            stopForegroundKeepNotification(app)
            if (changed || !serviceStarted) notify(app)
        }
    }

    /** Çalma bitti: bildirim, servis ve oturum kalkar. */
    fun clear(context: Context) {
        val app = context.applicationContext
        lastSignature = null
        playing = false
        try {
            app.stopService(Intent(app, MediaService::class.java))
        } catch (e: Exception) {
            // Servis zaten yoksa sorun değil.
        }
        serviceStarted = false
        try {
            notificationManager(app)?.cancel(NOTIFICATION_ID)
        } catch (e: Exception) {
            // Bildirim yöneticisi yoksa gösterilecek bildirim de yoktur.
        }
        session?.let {
            it.isActive = false
            it.release()
        }
        session = null
        coverBitmap = null
        coverBitmapPath = null
    }

    /** Uygulama açılışında bekleyen "bildirime dokunuldu" yükünü tüketir. */
    fun takePayload(): String? {
        val value = openPayload
        openPayload = null
        return value
    }

    /** MainActivity, bildirimden gelen intent'i buraya verir. */
    fun rememberPayload(value: String?) {
        if (!value.isNullOrEmpty()) openPayload = value
    }

    // ── Oturum ────────────────────────────────────────────────────────────

    private fun ensureSession(context: Context): MediaSession {
        session?.let { return it }
        val created = MediaSession(context, "DosyaOkuyucu")
        created.setCallback(object : MediaSession.Callback() {
            override fun onPlay() {
                onAction?.invoke(ACTION_PLAY, 0)
            }

            override fun onPause() {
                onAction?.invoke(ACTION_PAUSE, 0)
            }

            override fun onSkipToNext() {
                onAction?.invoke(ACTION_NEXT, 0)
            }

            override fun onSkipToPrevious() {
                onAction?.invoke(ACTION_PREVIOUS, 0)
            }

            override fun onStop() {
                onAction?.invoke(ACTION_STOP, 0)
            }

            override fun onSeekTo(pos: Long) {
                onAction?.invoke(ACTION_SEEK, pos)
            }

            override fun onFastForward() {
                onAction?.invoke(ACTION_SEEK, positionMs + 10_000L)
            }

            override fun onRewind() {
                val target = positionMs - 10_000L
                onAction?.invoke(ACTION_SEEK, if (target < 0) 0 else target)
            }
        })
        // API 21-30'da bayraklar olmadan oturum medya düğmelerini almıyor;
        // 31+'ta kullanımdan kalktılar ama çağırmak zararsız.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            created.setFlags(
                MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
        }
        session = created
        return created
    }

    private fun buildMetadata(context: Context): MediaMetadata {
        val builder = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, subtitle)
            .putString(MediaMetadata.METADATA_KEY_ALBUM, album)
            .putString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE, subtitle)
            // **Süre şart:** çubuğun sağ ucu buradan geliyor; verilmezse
            // sistem belirsiz (indeterminate) bir çubuk çiziyor.
            .putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs)
        cover(context)?.let {
            builder.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, it)
        }
        return builder.build()
    }

    private fun buildState(): PlaybackState {
        var actions = PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_STOP or
            PlaybackState.ACTION_SEEK_TO or
            PlaybackState.ACTION_FAST_FORWARD or
            PlaybackState.ACTION_REWIND
        if (hasNext) actions = actions or PlaybackState.ACTION_SKIP_TO_NEXT
        if (hasPrevious) actions = actions or PlaybackState.ACTION_SKIP_TO_PREVIOUS
        return PlaybackState.Builder()
            .setActions(actions)
            .setState(
                if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                positionMs,
                // Duraklatınca hız 0: yoksa sistem konumu ilerletmeye devam
                // eder ve çubuk duran müzikte akmaya devam ederdi.
                if (playing) speed else 0f
            )
            .build()
    }

    /**
     * Kapak resmi. Aynı yol iki kez çözülmez ve **ölçek düşürülür**: bir
     * albüm kapağı 3000×3000 gelebiliyor, onu her parçada tam çözmek düşük
     * bellekli telefonda uygulamayı öldürürdü.
     */
    private fun cover(context: Context): Bitmap? {
        val path = coverPath
        if (path.isNullOrEmpty()) {
            coverBitmap = null
            coverBitmapPath = null
            return null
        }
        if (path == coverBitmapPath) return coverBitmap
        val decoded = try {
            val bounds = BitmapFactory.Options()
            bounds.inJustDecodeBounds = true
            BitmapFactory.decodeFile(path, bounds)
            val longest = maxOf(bounds.outWidth, bounds.outHeight)
            val options = BitmapFactory.Options()
            var sample = 1
            while (longest / sample > 512) sample *= 2
            options.inSampleSize = sample
            BitmapFactory.decodeFile(path, options)
        } catch (e: Exception) {
            null
        } catch (e: OutOfMemoryError) {
            null
        }
        coverBitmap = decoded
        coverBitmapPath = if (decoded == null) null else path
        return decoded
    }

    // ── Bildirim ve ön plan servisi ───────────────────────────────────────

    private fun notificationManager(context: Context): NotificationManager? =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

    private fun ensureChannel(context: Context) {
        if (channelReady) return
        channelReady = true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Medya oynatıcı",
            // LOW: çalan her parçada ses/titreşim çıkarmasın.
            NotificationManager.IMPORTANCE_LOW
        )
        channel.setShowBadge(false)
        try {
            notificationManager(context)?.createNotificationChannel(channel)
        } catch (e: Exception) {
            // Kanal kurulamadıysa bildirim de görünmez; çalma yine sürer.
        }
    }

    private fun actionIntent(context: Context, action: String): PendingIntent {
        val intent = Intent(context, MediaService::class.java)
        intent.action = INTENT_PREFIX + action
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getService(context, action.hashCode(), intent, flags)
    }

    /**
     * Bildirime dokununca uygulamayı açan intent.
     *
     * Sınıfı adıyla (`MainActivity::class.java`) DEĞİL, paket yöneticisinin
     * verdiği açılış intent'iyle kuruluyor: böylece bu dosya `MainActivity`ye
     * hiç bağlı olmuyor ve `tool/check_kotlin.sh` onu Flutter olmadan tür
     * denetiminden geçirebiliyor. Activity `singleTask` olduğu için intent
     * açık uygulamaya `onNewIntent` ile düşer, yeni bir kopya açılmaz.
     */
    private fun contentIntent(context: Context): PendingIntent {
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_MAIN).setPackage(context.packageName)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.putExtra(EXTRA_PAYLOAD, payload)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getActivity(context, 1, intent, flags)
    }

    /** Bildirimi kurar. `MediaService` de ön plana geçerken bunu kullanır. */
    fun buildNotification(context: Context): Notification {
        ensureChannel(context)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder.setContentTitle(title)
            .setContentText(subtitle)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentIntent(contentIntent(context))
            .setDeleteIntent(actionIntent(context, ACTION_STOP))
            .setOngoing(playing)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
        if (album.isNotEmpty()) builder.setSubText(album)
        cover(context)?.let { builder.setLargeIcon(it) }

        // Düğme sırası: önceki · oynat/duraklat · sonraki · kapat.
        // Daraltılmış görünümde ilk üçü durur (compact view).
        val icons = context.applicationInfo.icon
        builder.addAction(
            Notification.Action.Builder(
                iconOf(android.R.drawable.ic_media_previous, icons),
                label(ACTION_PREVIOUS, "Önceki"),
                actionIntent(context, ACTION_PREVIOUS)
            ).build()
        )
        builder.addAction(
            Notification.Action.Builder(
                iconOf(
                    if (playing) android.R.drawable.ic_media_pause
                    else android.R.drawable.ic_media_play,
                    icons
                ),
                if (playing) label(ACTION_PAUSE, "Duraklat") else label(ACTION_PLAY, "Çal"),
                actionIntent(context, if (playing) ACTION_PAUSE else ACTION_PLAY)
            ).build()
        )
        builder.addAction(
            Notification.Action.Builder(
                iconOf(android.R.drawable.ic_media_next, icons),
                label(ACTION_NEXT, "Sonraki"),
                actionIntent(context, ACTION_NEXT)
            ).build()
        )
        builder.addAction(
            Notification.Action.Builder(
                iconOf(android.R.drawable.ic_menu_close_clear_cancel, icons),
                label(ACTION_STOP, "Kapat"),
                actionIntent(context, ACTION_STOP)
            ).build()
        )

        // **İşin özü:** oturum tokenı verilince Android bildirimi kendi medya
        // denetleyicisiyle çiziyor — ilerleme çubuğu, kapak ve kilit ekranı
        // kontrolleri buradan geliyor.
        val style = Notification.MediaStyle()
            .setShowActionsInCompactView(0, 1, 2)
        session?.sessionToken?.let { style.setMediaSession(it) }
        builder.setStyle(style)
        return builder.build()
    }

    private fun label(key: String, fallback: String): String {
        val value = labels[key]
        return if (value.isNullOrEmpty()) fallback else value
    }

    private fun iconOf(platform: Int, fallback: Int): Int =
        if (platform != 0) platform else fallback

    private fun startForeground(context: Context, changed: Boolean) {
        if (serviceStarted) {
            if (changed) notify(context)
            return
        }
        val intent = Intent(context, MediaService::class.java)
        intent.action = INTENT_PREFIX + "start"
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            serviceStarted = true
        } catch (e: Exception) {
            // Android 12+ arka plandan servis başlatmayı reddedebilir
            // (ForegroundServiceStartNotAllowedException). Düz bildirime
            // düşülür: çalma sürer, yalnız süreç koruması olmaz.
            notify(context)
        }
    }

    private fun stopForegroundKeepNotification(context: Context) {
        if (!serviceStarted) return
        serviceStarted = false
        try {
            val intent = Intent(context, MediaService::class.java)
            intent.action = INTENT_PREFIX + "detach"
            context.startService(intent)
        } catch (e: Exception) {
            // Servis durdurulamadıysa bildirim yine güncelleniyor.
        }
    }

    fun notify(context: Context) {
        try {
            notificationManager(context)?.notify(NOTIFICATION_ID, buildNotification(context))
        } catch (e: Exception) {
            // Bildirim izni yoksa sessizce geçilir — çalma etkilenmez.
        }
    }

    /** Servisten gelen düğme intent'i. */
    fun dispatchIntent(action: String?) {
        if (action == null || !action.startsWith(INTENT_PREFIX)) return
        val name = action.substring(INTENT_PREFIX.length)
        when (name) {
            ACTION_PLAY, ACTION_PAUSE, ACTION_NEXT, ACTION_PREVIOUS, ACTION_STOP ->
                onAction?.invoke(name, 0)
        }
    }
}

/**
 * Medyanın ön plan servisi.
 *
 * Tek işi süreci "kullanıcının gördüğü iş" sınıfında tutmak ve bildirimi
 * taşımak; çalma Dart tarafında. `stopWithTask="true"` DÜRÜSTLÜK GEREĞİ:
 * çalar Dart izolatında yaşıyor, uygulama görev listesinden atılınca izolat
 * ölür — ayakta kalan servis yalnız donmuş bir bildirim gösterirdi.
 */
class MediaService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == MediaBridge.INTENT_PREFIX + "detach") {
            stopForegroundCompat()
            MediaBridge.notify(this)
            return START_NOT_STICKY
        }
        try {
            val notification = MediaBridge.buildNotification(this)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    MediaBridge.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(MediaBridge.NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Ön plana geçilemediyse servis kendini kapatır; bildirim düz
            // bildirim olarak yine gösteriliyor.
            stopSelf()
        }
        MediaBridge.dispatchIntent(action)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForegroundCompat()
        super.onDestroy()
    }

    private fun stopForegroundCompat() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // DETACH: bildirim ekranda KALSIN (duraklatılmış müziğe
                // devam edilebilsin).
                stopForeground(STOP_FOREGROUND_DETACH)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(false)
            }
        } catch (e: Exception) {
            // Servis zaten ön planda değilse sorun yok.
        }
    }
}
