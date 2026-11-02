package com.dosyaokuyucu.dosya_okuyucu

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import org.json.JSONObject

/**
 * **Arka planda görünürlük — YALNIZ kişisel derleme** (DOSYA_KISISEL=1, 2026-11-02 kullanıcı isteği:
 * *"aktar menüsü ön planda olmasa dahi diğer dosya okuyucular görebilsin ve dosya gönderim isteği
 * atabilsin, bana bir onay gelsin; pil tüketimine dikkat edilmeli"*).
 *
 * * **Pil:** yalnız düşük güçlü BLE reklamı ([BleBeacon], ~1 sn aralık) + boşta bekleyen GATT sunucusu.
 *   Wi-Fi dinleme, uyanıklık kilidi, tarama YOK.
 * * **İstek:** gönderen (telefon ya da Windows "Dosya Aktar") GATT'a davet yazar → yüksek öncelikli
 *   bildirim "X n dosya göndermek istiyor · Reddet / Kabul et". Kabul uygulamayı `davet:` bağlantısıyla
 *   Yakındakiler'e açar; dosya oradan Wi-Fi ile gelir (BLE yalnız el sıkışma).
 * * **Ekranla çakışma:** Yakındakiler açıkken aynı UUID'yi ekran yayınlıyor; servis susar
 *   ([Control.pause]/[Control.resume], `NearbyBle`den).
 * * **Bildirim:** Android ön plan servisini bildirimsiz çalıştırmıyor. Kanal IMPORTANCE_MIN: durum
 *   çubuğunda simge yok, ses yok; Android 13+'ta kaydırıp kapatılabilir (servis sürer).
 *
 * Metinler Dart'tan (dil tablosu) gelir ve tercihlerde saklanır; servis süreç yeniden başlatılınca da
 * (START_STICKY) doğru dilde kurulur.
 */
@SuppressLint("MissingPermission")
class NearbyBgService : Service() {
    /** `NearbyBle`in yansımayla bulduğu denetim nesnesi (bkz. `nearbyBackground`). */
    object Control : NearbyBackground {
        @Volatile
        var paused = false

        override fun isOn(ctx: Context) = prefs(ctx).getBoolean(KEY_ON, false)

        override fun enable(ctx: Context, args: Map<String, Any?>): Boolean {
            val edit = prefs(ctx).edit().putBoolean(KEY_ON, true)
            for ((k, v) in args) if (v is String) edit.putString(k, v)
            edit.apply()
            running?.let {
                it.radio(!paused) // ad değişmiş olabilir: yayını yenile
                return true
            }
            return try {
                val intent = Intent(ctx, NearbyBgService::class.java)
                if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(intent) else ctx.startService(intent)
                true
            } catch (_: Exception) {
                prefs(ctx).edit().putBoolean(KEY_ON, false).apply()
                false
            }
        }

        override fun disable(ctx: Context) {
            prefs(ctx).edit().putBoolean(KEY_ON, false).apply()
            ctx.stopService(Intent(ctx, NearbyBgService::class.java))
        }

        override fun clearAsk(ctx: Context) {
            (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ASK_ID)
        }

        override fun pause() {
            paused = true
            running?.radio(false)
        }

        override fun resume() {
            paused = false
            running?.radio(true)
        }
    }

    companion object {
        private const val PREFS = "nearby_bg"
        private const val KEY_ON = "on"
        private const val CH_QUIET = "nearby_bg_quiet"
        private const val CH_ASK = "nearby_bg_ask"
        private const val NOTE_ID = 90420
        private const val ASK_ID = 90421
        private const val ACTION_REJECT = "nearby_bg.reject"

        @Volatile
        private var running: NearbyBgService? = null

        private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    private var beacon: BleBeacon? = null

    /** Bluetooth kapatılıp açılınca reklam kendiliğinden dönmez: yeniden başlat. */
    private val btState = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            if (i.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1) == BluetoothAdapter.STATE_ON) {
                radio(!Control.paused)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = this
        try {
            registerReceiver(btState, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED))
        } catch (_: Exception) {}
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_REJECT) {
            notifications().cancel(ASK_ID)
            return START_STICKY
        }
        if (!prefs(this).getBoolean(KEY_ON, false)) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            ensureChannels()
            val note = quietNotification()
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTE_ID, note, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            } else {
                startForeground(NOTE_ID, note)
            }
        } catch (_: Exception) {
            // Bluetooth izni yok ya da sistem arka plandan başlatmayı reddetti: sessizce kapan,
            // Yakındakiler'de anahtar yeniden açılınca tekrar denenir.
            stopSelf()
            return START_NOT_STICKY
        }
        radio(!Control.paused)
        return START_STICKY
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(btState)
        } catch (_: Exception) {}
        beacon?.stop()
        running = null
        super.onDestroy()
    }

    fun radio(on: Boolean) {
        if (!on) {
            beacon?.stop()
            return
        }
        val p = prefs(this)
        val b = beacon ?: BleBeacon(applicationContext) { _, bytes -> onInvite(bytes) }.also { beacon = it }
        try {
            b.start(p.getString("id", "") ?: "", p.getString("name", "") ?: "", lowPower = true)
        } catch (_: Exception) {}
    }

    /** GATT iş parçacığından gelir; bildirim yöneticisi iş parçacığı güvenli. */
    private fun onInvite(bytes: ByteArray) {
        if (bytes.isEmpty() || bytes.size > 4096) return
        val text = String(bytes, Charsets.UTF_8)
        val json = try {
            JSONObject(text)
        } catch (_: Exception) {
            return
        }
        val p = prefs(this)
        val from = json.optString("f", "?")
        val count = json.optInt("n", 0)
        val size = json.optLong("s", 0)
        var body = (p.getString("ask_body", null) ?: "{name}: {n}")
            .replace("{name}", from)
            .replace("{n}", count.toString())
        if (size > 0) body += " · " + human(size)
        val names = json.optJSONArray("a")
        val list = (0 until (names?.length() ?: 0)).joinToString("\n") { names!!.optString(it) }

        // Kabul: doğrudan alır. Bildirime dokunmak: uygulamada yine sorar (yanlışlıkla dokunuşa karşı).
        val accept = Extras.linkIntent(this, "davet:$text") ?: return
        val open = Extras.linkIntent(this, "davetsor:$text") ?: return
        val reject = PendingIntent.getService(
            this, ASK_ID,
            Intent(this, NearbyBgService::class.java).setAction(ACTION_REJECT),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val icon = Icon.createWithResource(this, applicationInfo.icon)
        val builder = builder(CH_ASK)
            .setContentTitle(p.getString("ask_title", "Dosya"))
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(if (list.isEmpty()) body else "$body\n$list"))
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .addAction(Notification.Action.Builder(icon, p.getString("reject", "Reddet"), reject).build())
            .addAction(Notification.Action.Builder(icon, p.getString("accept", "Kabul et"), accept).build())
        if (Build.VERSION.SDK_INT >= 26) {
            // Gönderen ~90 sn bekliyor; sonra bildirim kendiliğinden kalkar.
            builder.setTimeoutAfter(90_000)
        } else {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH).setDefaults(Notification.DEFAULT_ALL)
        }
        notifications().notify(ASK_ID, builder.build())
    }

    private fun quietNotification(): Notification {
        val p = prefs(this)
        val builder = builder(CH_QUIET)
            .setContentTitle(p.getString("bg_title", "Yakındakiler"))
            .setContentText(p.getString("bg_text", ""))
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setShowWhen(false)
        Extras.linkIntent(this, "app:nearby")?.let { builder.setContentIntent(it) }
        if (Build.VERSION.SDK_INT < 26) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_MIN)
        }
        return builder.build()
    }

    private fun builder(channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        val p = prefs(this)
        val quiet = NotificationChannel(
            CH_QUIET, p.getString("ch_quiet", "Arka planda görünürlük"), NotificationManager.IMPORTANCE_MIN
        )
        quiet.setShowBadge(false)
        notifications().createNotificationChannel(quiet)
        notifications().createNotificationChannel(
            NotificationChannel(CH_ASK, p.getString("ch_ask", "Gelen dosya istekleri"), NotificationManager.IMPORTANCE_HIGH)
        )
    }

    private fun notifications() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun human(bytes: Long): String {
        if (bytes < 1024) return "$bytes B"
        var v = bytes.toDouble()
        val units = arrayOf("KB", "MB", "GB", "TB")
        var u = -1
        do {
            v /= 1024
            u++
        } while (v >= 1024 && u < units.size - 1)
        return (if (v < 10) "%.1f" else "%.0f").format(v) + " " + units[u]
    }
}
