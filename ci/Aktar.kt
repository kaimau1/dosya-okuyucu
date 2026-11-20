package com.dosyaokuyucu.dosya_okuyucu

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * **Aktar şifrelemesinin hızlı yolu** (Faz G5, 2026-11-13) — Dart tarafı
 * `lib/services/fm/remote/peer_crypto.dart` `NativeAead`, kanal `dosya/aead`.
 *
 * Niye Kotlin: saf Dart AES-GCM (pointycastle) SFTP'yi 14 → 1 MB/sn düşürmüştü
 * (HAFIZA). `javax.crypto` Android'de Conscrypt/BoringSSL'e gider; ARMv8 AES +
 * PMULL komutlarıyla GB/sn düzeyinde. Kayıt başına (≤ 1 MiB) tek çağrı.
 *
 * Kanal **arka plan iş kuyruğunda**: şifreleme ana (arayüz) iş parçacığını
 * tutmaz. İki iş: `seal` (şifre + 16 bayt etiket sonda) ve `open` (etiket
 * tutmazsa `etiket` hatası).
 */
object AktarAead {
    const val CHANNEL = "dosya/aead"

    fun attach(messenger: BinaryMessenger) {
        val queue = messenger.makeBackgroundTaskQueue()
        MethodChannel(messenger, CHANNEL, StandardMethodCodec.INSTANCE, queue)
            .setMethodCallHandler { call, result ->
                val mode = when (call.method) {
                    "seal" -> Cipher.ENCRYPT_MODE
                    "open" -> Cipher.DECRYPT_MODE
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                var key: ByteArray? = null
                try {
                    key = call.argument<ByteArray>("k")
                    val nonce = call.argument<ByteArray>("n")
                    val data = call.argument<ByteArray>("d")
                    if (key == null || nonce == null || data == null) {
                        result.error("args", null, null)
                        return@setMethodCallHandler
                    }
                    val aad = call.argument<ByteArray>("a") ?: ByteArray(0)
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(mode, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
                    if (aad.isNotEmpty()) cipher.updateAAD(aad)
                    result.success(cipher.doFinal(data))
                } catch (e: AEADBadTagException) {
                    result.error("etiket", null, null)
                } catch (e: Exception) {
                    result.error("yerel", e.javaClass.simpleName, null)
                } finally {
                    key?.fill(0)
                }
            }
    }
}

/**
 * **"Dosya al" Hızlı Ayarlar kutucuğu** (2026-11-13 kullanıcı isteği: uygulamayı açmadan alıcı
 * kipini aç/kapa). Kutucuk [AktarAlServisi]'ni başlatır/durdurur.
 *
 * Servis bir ön plan servisidir ve içinde başsız (ekransız) bir Flutter motoru koşar: Dart
 * `lib/services/fm/remote/tile_receiver.dart` `aktarKutucukAlici` aynı `PeerReceiver`'ı (şifreli
 * protokol dahil) çalıştırır — alıcı kodu iki kez yazılmadı. Ekransız olduğu için onay penceresi
 * yok: YALNIZ anahtarıyla güvenilen cihazlardan şifreli gelen dosya alınır; ötekiler reddedilir ve
 * "Aktar'ı aç" bildirimi çıkar. 30 dk boşta kalırsa kendini kapatır. Aktar ekranı açılınca servis
 * durur (aynı port/yayın tek sahipte).
 */
class AktarAlServisi : android.app.Service() {
    companion object {
        const val CHANNEL = "dosya/kutucuk"
        private const val NOTIF_ID = 90611
        private const val INFO_ID = 90612
        private const val CH = "aktar_al"

        @Volatile
        var running: AktarAlServisi? = null

        fun prefs(ctx: android.content.Context) =
            ctx.getSharedPreferences("aktar_kutucuk", android.content.Context.MODE_PRIVATE)

        fun start(ctx: android.content.Context): Boolean = try {
            val i = android.content.Intent(ctx, AktarAlServisi::class.java)
            if (android.os.Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
            true
        } catch (e: Exception) {
            false
        }

        fun stop(ctx: android.content.Context) {
            try {
                ctx.stopService(android.content.Intent(ctx, AktarAlServisi::class.java))
            } catch (_: Exception) {
            }
        }

        /** Ana motorun kanalı: durum, durdur, bildirim metinleri (dil tablosundan). */
        fun attachMain(ctx: android.content.Context, messenger: BinaryMessenger) {
            val app = ctx.applicationContext
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "running" -> result.success(running != null)
                    "stop" -> { stop(app); result.success(true) }
                    "texts" -> {
                        val e = prefs(app).edit()
                        (call.arguments as? Map<*, *>)?.forEach { (k, v) ->
                            if (k is String && v is String) e.putString(k, v)
                        }
                        e.apply()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private var engine: io.flutter.embedding.engine.FlutterEngine? = null

    private fun text(key: String, fallback: String) = prefs(this).getString(key, null) ?: fallback

    override fun onBind(intent: android.content.Intent?): android.os.IBinder? = null

    override fun onStartCommand(intent: android.content.Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") {
            if (running == null) foreground()
            stopSelf()
            return START_NOT_STICKY
        }
        if (!foreground()) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (engine == null && !startEngine()) {
            stopSelf()
            return START_NOT_STICKY
        }
        running = this
        refreshTile()
        return START_NOT_STICKY
    }

    /** Android 15+ (targetSdk 36): dataSync ön plan servisi süre sınırına ulaşınca kendini kapatmalı. */
    override fun onTimeout(startId: Int, fgsType: Int) {
        stopSelf()
    }

    private fun manager() =
        getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

    private fun channel() {
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            manager().createNotificationChannel(
                android.app.NotificationChannel(
                    CH, text("channel", "Dosya alımı"), android.app.NotificationManager.IMPORTANCE_LOW
                )
            )
        }
    }

    private fun builder(): android.app.Notification.Builder =
        if (android.os.Build.VERSION.SDK_INT >= 26) android.app.Notification.Builder(this, CH)
        else @Suppress("DEPRECATION") android.app.Notification.Builder(this)

    private fun openApp(): android.app.PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        return android.app.PendingIntent.getActivity(
            this, 0, launch, android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun foreground(): Boolean = try {
        channel()
        val stopPi = android.app.PendingIntent.getService(
            this, 1, android.content.Intent(this, AktarAlServisi::class.java).setAction("stop"),
            android.app.PendingIntent.FLAG_IMMUTABLE
        )
        val b = builder()
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(text("title", "Dosya alımı açık"))
            .setContentText(text("body", "Güvenilen cihazlar şifreli dosya gönderebilir"))
            .setOngoing(true)
            .addAction(android.app.Notification.Action.Builder(null, text("stop", "Kapat"), stopPi).build())
        openApp()?.let { b.setContentIntent(it) }
        if (android.os.Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, b.build(), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID, b.build())
        }
        true
    } catch (_: Exception) {
        false
    }

    private fun info(title: String, body: String) {
        val b = builder().setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(title).setContentText(body).setAutoCancel(true)
        openApp()?.let { b.setContentIntent(it) }
        try {
            manager().notify(INFO_ID, b.build())
        } catch (e: SecurityException) {
            // Bildirim izni yok: dosya yine alınır.
        }
    }

    private fun startEngine(): Boolean {
        return try {
            val loader = io.flutter.FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val e = io.flutter.embedding.engine.FlutterEngine(applicationContext)
            try {
                AktarAead.attach(e.dartExecutor.binaryMessenger)
                MethodChannel(e.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                    when (call.method) {
                        "received" -> {
                            val name = call.argument<String>("name") ?: ""
                            val from = call.argument<String>("from") ?: "?"
                            info(text("got", "Dosya alındı"), "$name · $from")
                            result.success(null)
                        }
                        "asked" -> {
                            val from = call.argument<String>("from") ?: "?"
                            info(text("refused", "Güvenilmeyen cihazdan istek reddedildi"),
                                "$from · ${text("open", "Almak için Aktar'ı aç")}")
                            result.success(null)
                        }
                        "stop" -> { stopSelf(); result.success(null) }
                        "running" -> result.success(true)
                        else -> result.notImplemented()
                    }
                }
                e.dartExecutor.executeDartEntrypoint(
                    io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "package:dosya_okuyucu/services/fm/remote/tile_receiver.dart",
                        "aktarKutucukAlici"
                    )
                )
                engine = e
                true
            } catch (t: Throwable) {
                e.destroy()
                false
            }
        } catch (_: Throwable) {
            false
        }
    }

    override fun onDestroy() {
        engine?.destroy()
        engine = null
        running = null
        refreshTile()
        super.onDestroy()
    }

    private fun refreshTile() {
        if (android.os.Build.VERSION.SDK_INT >= 24) {
            try {
                android.service.quicksettings.TileService.requestListeningState(
                    this, android.content.ComponentName(this, AktarKutucuk::class.java)
                )
            } catch (e: Exception) {
                // Kutucuk eklenmemiş olabilir.
            }
        }
    }
}

@androidx.annotation.RequiresApi(24)
class AktarKutucuk : android.service.quicksettings.TileService() {
    override fun onStartListening() {
        super.onStartListening()
        show(AktarAlServisi.running != null)
    }

    override fun onClick() {
        super.onClick()
        if (AktarAlServisi.running != null) {
            AktarAlServisi.stop(this)
            show(false)
            return
        }
        if (AktarAlServisi.start(this)) {
            show(true)
            return
        }
        // Android ön plan servisini kutucuktan başlatmaya izin vermediyse: uygulamayı aç.
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launch.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        if (android.os.Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(
                android.app.PendingIntent.getActivity(this, 0, launch, android.app.PendingIntent.FLAG_IMMUTABLE)
            )
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(launch)
        }
    }

    private fun show(on: Boolean) {
        val t = qsTile ?: return
        t.state = if (on) android.service.quicksettings.Tile.STATE_ACTIVE else android.service.quicksettings.Tile.STATE_INACTIVE
        t.updateTile()
    }
}
