package com.dosyaokuyucu.dosya_okuyucu

import android.app.Activity
import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.os.Build
import android.os.CancellationSignal
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.text.format.Formatter
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/**
 * **Yerel ekler** (2026-10-18 turu) — `lib/services/fm/native_extras.dart`in
 * Android yüzü. Yalnız Android çerçevesine bağlı (Flutter yok): böylece
 * `tool/check_kotlin.sh` gerçek API jar'ına karşı derleyip JVM'de deneyebiliyor.
 *
 * 1. **Günlük iş** ([DailyJob], JobScheduler, ~12 saatte bir, yeniden
 *    başlatmadan sonra da kurulu): fatura son ödeme hatırlatması + haftalık
 *    temizlik önerisi. Dart yalnız VERİ yazar (hatırlatmalar, çevrilmiş
 *    metinler); karar ve bildirim burada — uygulama kapalıyken de çalışsın.
 * 2. **Ana ekran widget'ları** ([StorageWidget], [RecentWidget]).
 * 3. **Parmak izi** (çerçevenin BiometricPrompt'u, Android 9+) ve kasa
 *    anahtarını Android Keystore ile sarma.
 * 4. **Konum adı** (Geocoder) — fotoğraf yerleri.
 *
 * Widget/bildirim dokunuşu uygulamayı [EXTRA_LINK] ile açar; `MainActivity`
 * bağlantıyı Dart'a iletir (`app:scan`, `app:bills`, `file:/yol`…).
 */
object Extras {
    const val CHANNEL = "dosya/extras"

    /**
     * **Önceki süreç neden öldü?** (2026-11-03, kullanıcı: *"iyileştir başlıyor,
     * kısa süre sonra uygulama kapanıyor"*). Yerel çökme, bellek öldürmesi ve
     * ANR Dart hata yakalayıcısına hiç düşmüyordu; Hata kayıtları boş kalıyor,
     * kök neden telefona adb bağlamadan bulunamıyordu. Android 11+.
     * [since] (ms) sonrasındaki kayıtlar, en yeni önce.
     */
    fun exitReasons(ctx: Context, since: Long): List<Map<String, Any>> {
        if (Build.VERSION.SDK_INT < 30) return emptyList()
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val wanted = mapOf(
            android.app.ApplicationExitInfo.REASON_CRASH to "crash",
            android.app.ApplicationExitInfo.REASON_CRASH_NATIVE to "native_crash",
            android.app.ApplicationExitInfo.REASON_LOW_MEMORY to "low_memory",
            android.app.ApplicationExitInfo.REASON_ANR to "anr",
            android.app.ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE to "excessive_resource",
            android.app.ApplicationExitInfo.REASON_SIGNALED to "signaled",
        )
        return am.getHistoricalProcessExitReasons(ctx.packageName, 0, 5)
            .filter { it.timestamp > since && wanted.containsKey(it.reason) }
            .map {
                mapOf(
                    "time" to it.timestamp,
                    "reason" to (wanted[it.reason] ?: "?"),
                    "description" to (it.description ?: ""),
                    "status" to it.status,
                    "pssKb" to it.pss,
                    "rssKb" to it.rss,
                    "importance" to it.importance,
                )
            }
    }

    /**
     * **Cihaz sınıfı** (Faz 4, 2026-10-21): Dart tarafı bütçeleri (görsel
     * önbelleği, küçük resim eşzamanlılığı, 120 Hz varsayılanı) buna göre
     * seçer — bkz. `lib/core/device_profile.dart`.
     */
    fun deviceClass(ctx: Context): Map<String, Any> {
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        val perfClass = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Build.VERSION.MEDIA_PERFORMANCE_CLASS
        } else {
            0
        }
        return mapOf(
            "totalRamMb" to (info.totalMem / (1024L * 1024L)),
            "lowRam" to am.isLowRamDevice,
            "cores" to Runtime.getRuntime().availableProcessors(),
            "perfClass" to perfClass,
            "sdk" to Build.VERSION.SDK_INT,
        )
    }
    const val EXTRA_LINK = "dosya_link"
    /** G1.2 (B4): [EXTRA_LINK] / kısayol yolu için HMAC-SHA256 imzası (hex). */
    const val EXTRA_SIG = "dosya_sig"
    private const val LINK_KEY_FILE = "link_key"

    @Volatile
    private var cachedLinkKey: ByteArray? = null

    @Volatile
    var activityVisible: Boolean = false

    @Volatile
    internal var activeSmartJob: SmartBgJob? = null

    fun stopSmartJobIfRunning() {
        activeSmartJob?.stopFromForeground()
    }

    /**
     * Bağlantı imza anahtarı: ilk kullanımda 32 rastgele bayt, `filesDir/link_key`.
     * Kalıcı (sabitlenmiş kısayol/widget uygulama kapanıp açılınca da geçerli kalsın);
     * yedeğe girmez (allowBackup=false). Başka uygulama okuyamaz.
     */
    @Synchronized
    fun linkKey(ctx: Context): ByteArray {
        cachedLinkKey?.let { return it }
        val f = File(ctx.filesDir, LINK_KEY_FILE)
        try {
            if (f.isFile && f.length() == 32L) {
                val read = f.readBytes()
                if (read.size == 32) {
                    cachedLinkKey = read
                    return read
                }
            }
        } catch (_: Exception) {
        }
        val key = ByteArray(32).also { SecureRandom().nextBytes(it) }
        try {
            val tmp = File(ctx.filesDir, "$LINK_KEY_FILE.tmp")
            tmp.writeBytes(key)
            if (!tmp.renameTo(f)) {
                tmp.delete()
                f.writeBytes(key)
            }
        } catch (_: Exception) {
        }
        cachedLinkKey = key
        return key
    }

    fun hmacHex(key: ByteArray, text: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(text.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }

    fun sign(ctx: Context, text: String): String = hmacHex(linkKey(ctx), text)

    fun sigOk(key: ByteArray, text: String, sig: String?): Boolean {
        if (sig.isNullOrEmpty()) return false
        return MessageDigest.isEqual(
            hmacHex(key, text).toByteArray(Charsets.UTF_8),
            sig.toByteArray(Charsets.UTF_8)
        )
    }

    /**
     * Yolun özel uygulama dizinlerine (`/data/`, `/data_mirror/`), sistem
     * dizinlerine (`/proc/`, `/sys/`, `/etc/`), `Android/data` / `Android/obb`
     * veya kasa dizinlerine işaret etmediğini kanonik yolla doğrular.
     */
    fun isSafeExternalPath(path: String?): Boolean {
        if (path.isNullOrEmpty() || !path.startsWith("/") || path.indexOf('\u0000') >= 0) return false
        if (path.split('/').contains("..")) return false
        val c = try { File(path).canonicalPath } catch (_: Exception) { return false }
        for (p in listOf(path, c)) {
            if (p.startsWith("/data/") || p == "/data" ||
                p.startsWith("/data_mirror/") || p == "/data_mirror" ||
                p.startsWith("/proc/") || p == "/proc" ||
                p.startsWith("/sys/") || p == "/sys" ||
                p.startsWith("/etc/") || p == "/etc"
            ) return false
            if (p.contains("/Android/data/") || p.endsWith("/Android/data") ||
                p.contains("/Android/obb/") || p.endsWith("/Android/obb")
            ) return false
            if (p.split('/').any {
                    it.equals(".DosyaOkuyucuKasa", ignoreCase = true) ||
                        it.equals(".DosyaOkuyucuGizli", ignoreCase = true) ||
                        it == "vault_open"
                }) return false
        }
        return true
    }

    /**
     * Dışarıdan gelebilecek [EXTRA_LINK]'i süz. İmzalı → kabul (`file:` ise
     * ayrıca yol güvenli olmalı). İmzasız → yalnız `app:` (salt gezinme;
     * başlatıcı kısayolları XML'den sabit gelir, imzalanamaz).
     * `file:`, `davet:` vb. imzasızsa YOK SAYILIR.
     */
    fun linkAccepted(link: String?, sig: String?, key: ByteArray): Boolean {
        if (link.isNullOrEmpty()) return false
        if (link.startsWith("file:") && !isSafeExternalPath(link.removePrefix("file:"))) {
            return false
        }
        if (sigOk(key, link, sig)) return true
        return link.startsWith("app:")
    }

    /**
     * Kısayol yolunu süz. İmzalı → kabul (güvenli dış yol ise). İmzasız (bu
     * sürümden önce sabitlenmiş ana ekran kısayolları imzasızdır; kırılmasın)
     * → yalnız özel uygulama dizinleri dışındaki mutlak yol.
     * G1 artığı (2026-11-14): [ownShortcuts] verilirse (API 26+, sistemin bildiği
     * kendi sabitli/dinamik kısayollarımızın yolları) imzasız yol YALNIZ bu
     * kümedeyse geçer.
     */
    fun pathAccepted(
        path: String?,
        sig: String?,
        key: ByteArray,
        ownShortcuts: Set<String>? = null,
    ): Boolean {
        if (!isSafeExternalPath(path)) return false
        if (sigOk(key, path!!, sig)) return true
        if (ownShortcuts != null && path !in ownShortcuts) return false
        return true
    }
    const val JOB_ID = 0x5E01
    private const val PREFS = "dosya_extras"
    private const val KEY_DAILY = "daily"
    private const val KEY_WIDGET = "widget"
    private const val KEY_LAST_CLEAN = "last_clean_notify"
    private const val KEY_NOTIFIED = "notified"
    private const val NOTIFY_CHANNEL = "dosya_reminders"
    private const val NOTIFY_CLEAN = 0x5E10
    private const val NOTIFY_BILL_BASE = 0x5E20
    private const val KEY_ALIAS = "dosya_vault_key"
    private const val BIO_ALIAS = "dosya_vault_bio_v2"
    const val DAY_MS = 24L * 60 * 60 * 1000

    /** Temizlik bildirimi için doluluk eşiği (%) ve bilinen gereksiz boyut eşiği. */
    const val CLEAN_PCT = 80
    const val CLEAN_BYTES = 500L * 1024 * 1024

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ── bağlantılar ────────────────────────────────────────────────────────

    /** Uygulamayı [link] ile açan PendingIntent (her bağlantı kendi kodu). */
    fun linkIntent(ctx: Context, link: String): PendingIntent? {
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            ?: return null
        launch.putExtra(EXTRA_LINK, link)
        launch.putExtra(EXTRA_SIG, sign(ctx, link))
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        // Ayrı istek kodu: aynı kodla FLAG_UPDATE_CURRENT öteki bağlantının
        // ekini ezerdi (dört widget düğmesi aynı hedefi açardı).
        return PendingIntent.getActivity(
            ctx, link.hashCode(), launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    // ── 1. günlük iş ───────────────────────────────────────────────────────

    /** Dart'tan gelen ayarı saklar ve işi kurar. */
    fun configureDaily(ctx: Context, json: String): Boolean {
        if (runCatching { JSONObject(json) }.isFailure) return false
        prefs(ctx).edit().putString(KEY_DAILY, json).apply()
        return schedule(ctx)
    }

    // ── Akıllı düzen arka plan işi (2026-11-19) ────────────────────────────
    const val SMART_JOB_ID = 0x5E02

    /** Şarjda + ölçülü olmayan ağda ~saatte bir [SmartBgJob]; [on] false iptal. */
    fun scheduleSmartBg(ctx: Context, on: Boolean): Boolean {
        val scheduler = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
            ?: return false
        if (!on) {
            scheduler.cancel(SMART_JOB_ID)
            return true
        }
        // 2026-11-22: 3 sa → 1 sa (kullanıcı: "bitmiyor"); eski aralıklı iş
        // varsa yenisiyle değiştirilir.
        val interval = TimeUnit.HOURS.toMillis(1)
        val pending = scheduler.getPendingJob(SMART_JOB_ID)
        if (pending != null && pending.intervalMillis == interval) return true
        val info = JobInfo.Builder(SMART_JOB_ID, ComponentName(ctx, SmartBgJob::class.java))
            .setPeriodic(interval)
            .setRequiresCharging(true)
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_UNMETERED)
            .setPersisted(true)
            .build()
        return runCatching { scheduler.schedule(info) == JobScheduler.RESULT_SUCCESS }
            .getOrDefault(false)
    }

    fun isCharging(ctx: Context): Boolean {
        val bm = ctx.getSystemService(Context.BATTERY_SERVICE) as? android.os.BatteryManager
            ?: return false
        return bm.isCharging
    }

    fun schedule(ctx: Context): Boolean {
        val scheduler = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
            ?: return false
        if (scheduler.getPendingJob(JOB_ID) != null) return true
        val info = JobInfo.Builder(JOB_ID, ComponentName(ctx, DailyJob::class.java))
            .setPeriodic(TimeUnit.HOURS.toMillis(12))
            .setPersisted(true)
            .build()
        return runCatching { scheduler.schedule(info) == JobScheduler.RESULT_SUCCESS }
            .getOrDefault(false)
    }

    /** Bir hatırlatma: kalan gün (bugün 0, geçmiş negatif). Saf, test edilir. */
    fun daysLeft(dueMs: Long, nowMs: Long): Int {
        val cal = java.util.Calendar.getInstance()
        cal.timeInMillis = nowMs
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        val today = cal.timeInMillis
        return Math.floorDiv(dueMs - today, DAY_MS).toInt()
    }

    /** Hatırlatma bu gün söylenmeli mi? (0..[remindDays] ya da en çok 7 gün geçmiş) */
    fun shouldRemind(days: Int, remindDays: Int): Boolean = days in -7..remindDays

    /** Temizlik bildirimi gerekli mi? Saf, test edilir. */
    fun shouldSuggestClean(
        enabled: Boolean, usedPct: Int, recoverable: Long, lastMs: Long, nowMs: Long
    ): Boolean = enabled &&
        nowMs - lastMs >= 7 * DAY_MS &&
        (usedPct >= CLEAN_PCT || recoverable >= CLEAN_BYTES)

    /** Günlük işin gövdesi (JobService ve deneme tezgâhı çağırır). */
    fun runDaily(ctx: Context, nowMs: Long = System.currentTimeMillis()) {
        val cfg = runCatching { JSONObject(prefs(ctx).getString(KEY_DAILY, null) ?: return) }
            .getOrNull() ?: return
        val strings = cfg.optJSONObject("strings") ?: JSONObject()
        val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        ensureChannel(ctx, manager, strings.optString("channel", "Dosya Okuyucu"))
        val stamp = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date(nowMs))
        val notified = prefs(ctx).getStringSet(KEY_NOTIFIED, emptySet())!!.toMutableSet()
        // Eski damgalar atılır (küme sonsuza dek büyümesin).
        notified.removeAll { !it.endsWith("|$stamp") && !it.startsWith("over|") }

        // Faturalar.
        val reminders = cfg.optJSONArray("reminders")
        val remindDays = cfg.optInt("remindDays", 3)
        if (reminders != null) {
            for (i in 0 until reminders.length()) {
                val r = reminders.optJSONObject(i) ?: continue
                val due = r.optLong("due", 0)
                if (due <= 0) continue
                val days = daysLeft(due, nowMs)
                if (!shouldRemind(days, remindDays)) continue
                val title = r.optString("title")
                // Geçmişse yalnız BİR kez; değilse günde bir kez.
                val key = if (days < 0) "over|$title|$due" else "bill|$title|$due|$stamp"
                if (!notified.add(key)) continue
                val amount = r.optString("amount")
                val body = when {
                    days < 0 -> strings.optString("bill_overdue")
                    days == 0 -> strings.optString("bill_today")
                    else -> strings.optString("bill_body")
                }.replace("{amount}", amount).replace("{days}", days.toString())
                    .trim().trimStart('·').trim()
                notify(
                    ctx, manager, NOTIFY_BILL_BASE + (i % 32),
                    strings.optString("bill_title").replace("{title}", title),
                    body, "app:bills"
                )
            }
        }

        // Haftalık temizlik.
        val pct = usedPercent()
        val last = prefs(ctx).getLong(KEY_LAST_CLEAN, 0)
        val recoverable = cfg.optLong("recoverable", 0)
        if (shouldSuggestClean(cfg.optBoolean("cleanup", true), pct, recoverable, last, nowMs)) {
            val body = if (recoverable > 0) {
                strings.optString("clean_body_found")
                    .replace("{size}", Formatter.formatShortFileSize(ctx, recoverable))
            } else {
                strings.optString("clean_body")
            }.replace("{pct}", pct.toString())
            notify(ctx, manager, NOTIFY_CLEAN, strings.optString("clean_title"), body, "app:clean")
            prefs(ctx).edit().putLong(KEY_LAST_CLEAN, nowMs).apply()
        }
        prefs(ctx).edit().putStringSet(KEY_NOTIFIED, notified).apply()
    }

    private fun ensureChannel(ctx: Context, manager: NotificationManager, name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        manager.createNotificationChannel(
            NotificationChannel(NOTIFY_CHANNEL, name, NotificationManager.IMPORTANCE_DEFAULT)
        )
    }

    private fun notify(
        ctx: Context, manager: NotificationManager, id: Int,
        title: String, body: String, link: String
    ) {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(ctx, NOTIFY_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(ctx)
        }
        linkIntent(ctx, link)?.let { builder.setContentIntent(it) }
        runCatching {
            manager.notify(
                id,
                builder.setSmallIcon(ctx.applicationInfo.icon)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setStyle(android.app.Notification.BigTextStyle().bigText(body))
                    .setAutoCancel(true)
                    .build()
            )
        }
    }

    /** Ana belleğin doluluk yüzdesi. */
    fun usedPercent(): Int = runCatching {
        val stat = StatFs(Environment.getExternalStorageDirectory().path)
        val total = stat.totalBytes
        if (total <= 0) 0 else ((total - stat.availableBytes) * 100 / total).toInt()
    }.getOrDefault(0)

    // ── 2. widget'lar ──────────────────────────────────────────────────────

    fun saveWidgetData(ctx: Context, json: String): Boolean {
        if (runCatching { JSONObject(json) }.isFailure) return false
        prefs(ctx).edit().putString(KEY_WIDGET, json).apply()
        updateWidgets(ctx)
        return true
    }

    fun updateWidgets(ctx: Context) {
        val manager = AppWidgetManager.getInstance(ctx) ?: return
        val storageIds = manager.getAppWidgetIds(ComponentName(ctx, StorageWidget::class.java))
        if (storageIds.isNotEmpty()) StorageWidget.render(ctx, manager, storageIds)
        val recentIds = manager.getAppWidgetIds(ComponentName(ctx, RecentWidget::class.java))
        if (recentIds.isNotEmpty()) RecentWidget.render(ctx, manager, recentIds)
    }

    fun widgetData(ctx: Context): JSONObject =
        runCatching { JSONObject(prefs(ctx).getString(KEY_WIDGET, null) ?: "{}") }
            .getOrDefault(JSONObject())

    // ── 3. biyometri + Keystore ────────────────────────────────────────────

    fun canAuthenticate(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bm = ctx.getSystemService(android.hardware.biometrics.BiometricManager::class.java)
                ?: return false
            return bm.canAuthenticate(
                android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG
            ) == android.hardware.biometrics.BiometricManager.BIOMETRIC_SUCCESS
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val bm = ctx.getSystemService(android.hardware.biometrics.BiometricManager::class.java)
                ?: return false
            @Suppress("DEPRECATION")
            return bm.canAuthenticate() == android.hardware.biometrics.BiometricManager.BIOMETRIC_SUCCESS
        }
        val keyguard = ctx.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        return ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT) &&
            keyguard?.isDeviceSecure == true
    }

    /** Biyometrik pencere; sonuç ana izlekte [done]a. */
    fun authenticate(
        activity: Activity, title: String, subtitle: String, cancel: String,
        done: (Boolean) -> Unit
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            done(false)
            return
        }
        val executor = activity.mainExecutor
        var answered = false
        fun answer(ok: Boolean) {
            if (!answered) {
                answered = true
                done(ok)
            }
        }
        val builder = android.hardware.biometrics.BiometricPrompt.Builder(activity)
            .setTitle(title)
            .setNegativeButton(cancel, executor) { _, _ -> answer(false) }
        if (subtitle.isNotEmpty()) builder.setSubtitle(subtitle)
        val prompt = builder.build()
        prompt.authenticate(
            CancellationSignal(), executor,
            object : android.hardware.biometrics.BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: android.hardware.biometrics.BiometricPrompt.AuthenticationResult?
                ) {
                    answer(true)
                }

                override fun onAuthenticationError(code: Int, msg: CharSequence?) {
                    answer(false)
                }
            }
        )
    }

    @Synchronized
    private fun vaultKey(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    /** iv(12) + şifreli metin; hata → null. */
    fun wrap(plain: ByteArray): ByteArray? = runCatching {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, vaultKey())
        cipher.iv + cipher.doFinal(plain)
    }.getOrNull()

    fun unwrap(blob: ByteArray): ByteArray? = runCatching {
        if (blob.size < 13) return null
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, vaultKey(), GCMParameterSpec(128, blob, 0, 12))
        cipher.doFinal(blob, 12, blob.size - 12)
    }.getOrNull()

    // ── 3b. G3 (2026-11-11): PIN türetme + kimlik doğrulama zorunlu kasa anahtarı ──

    /** PBKDF2-HMAC-SHA256 (32 bayt) arka izlekte; Android 8 altı/hata → null. */
    fun pbkdf2(pin: String, salt: ByteArray, iter: Int, done: (ByteArray?) -> Unit) {
        val main = Handler(Looper.getMainLooper())
        Thread {
            val out = runCatching {
                val chars = pin.toCharArray()
                val spec = PBEKeySpec(chars, salt, iter, 256)
                try {
                    SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                        .generateSecret(spec).encoded
                } finally {
                    spec.clearPassword()
                    chars.fill('\u0000')
                }
            }.getOrNull()
            main.post { done(out) }
        }.start()
    }

    /**
     * Kasa ana anahtarını sarar/açar; anahtar `setUserAuthenticationRequired`
     * ile üretilir ve her kullanımda BiometricPrompt `CryptoObject` ister —
     * eski [wrap] (Gemini/uzak parolalar da kullanır, DEĞİŞMEDİ) yalnız
     * arayüz kapısıydı. Yeni parmak izi eklenince anahtar geçersizleşir.
     */
    fun bioCrypt(
        activity: Activity, encrypt: Boolean, data: ByteArray,
        title: String, subtitle: String, cancel: String,
        done: (Map<String, Any?>) -> Unit
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            done(mapOf("status" to "error"))
            return
        }
        val cipher = try {
            Cipher.getInstance("AES/GCM/NoPadding").apply {
                if (encrypt) {
                    init(Cipher.ENCRYPT_MODE, bioKey(create = true))
                } else {
                    if (data.size < 13) throw IllegalArgumentException("kısa")
                    val key = bioKey(create = false) ?: throw KeyPermanentlyInvalidatedException()
                    init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, data, 0, 12))
                }
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            bioDeleteKey()
            done(mapOf("status" to "invalidated"))
            return
        } catch (e: Exception) {
            done(mapOf("status" to "error"))
            return
        }
        val executor = activity.mainExecutor
        var answered = false
        fun answer(map: Map<String, Any?>) {
            if (!answered) { answered = true; done(map) }
        }
        val builder = android.hardware.biometrics.BiometricPrompt.Builder(activity)
            .setTitle(title)
            .setNegativeButton(cancel, executor) { _, _ -> answer(mapOf("status" to "cancel")) }
        if (subtitle.isNotEmpty()) builder.setSubtitle(subtitle)
        builder.build().authenticate(
            android.hardware.biometrics.BiometricPrompt.CryptoObject(cipher),
            CancellationSignal(), executor,
            object : android.hardware.biometrics.BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: android.hardware.biometrics.BiometricPrompt.AuthenticationResult?
                ) {
                    val c = result?.cryptoObject?.cipher
                    val out = runCatching {
                        if (c == null) null
                        else if (encrypt) c.iv + c.doFinal(data)
                        else c.doFinal(data, 12, data.size - 12)
                    }.getOrNull()
                    answer(
                        if (out == null) mapOf("status" to "error")
                        else mapOf("status" to "ok", "data" to out)
                    )
                }

                override fun onAuthenticationError(code: Int, msg: CharSequence?) {
                    answer(mapOf("status" to "cancel"))
                }
            }
        )
    }

    @Synchronized
    private fun bioKey(create: Boolean): SecretKey? {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(BIO_ALIAS, null) as? SecretKey)?.let { return it }
        if (!create) return null
        val spec = KeyGenParameterSpec.Builder(
            BIO_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .build()
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(spec)
        return gen.generateKey()
    }

    fun bioDeleteKey() {
        runCatching {
            KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.deleteEntry(BIO_ALIAS)
        }
    }

    // ── 4. konum adı ───────────────────────────────────────────────────────

    /** Semt/şehir adı; arka izlekte çalışır, sonuç ana izlekte. */
    fun geocode(ctx: Context, lat: Double, lon: Double, lang: String, done: (String?) -> Unit) {
        val main = Handler(Looper.getMainLooper())
        Thread {
            val name = runCatching {
                if (!Geocoder.isPresent()) return@runCatching null
                val locale = if (lang == "system" || lang.isEmpty()) Locale.getDefault()
                else Locale(lang)
                @Suppress("DEPRECATION")
                val list = Geocoder(ctx, locale).getFromLocation(lat, lon, 1)
                val a = list?.firstOrNull() ?: return@runCatching null
                listOfNotNull(
                    a.subLocality ?: a.subAdminArea,
                    a.locality ?: a.adminArea,
                ).distinct().joinToString(", ").ifEmpty { a.countryName }
            }.getOrNull()
            main.post { done(name) }
        }.start()
    }
}

/** ~12 saatte bir: hatırlatmalar + haftalık temizlik. */
class DailyJob : JobService() {
    @Volatile
    private var worker: Thread? = null

    override fun onStartJob(params: JobParameters?): Boolean {
        val t = Thread {
            if (!Thread.currentThread().isInterrupted) {
                runCatching { Extras.runDaily(applicationContext) }
            }
            if (!Thread.currentThread().isInterrupted) {
                runCatching { Extras.updateWidgets(applicationContext) }
            }
            worker = null
            jobFinished(params, false)
        }
        worker = t
        t.start()
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        worker?.interrupt()
        worker = null
        return true
    }
}

/**
 * **Akıllı düzen arka plan turu** (2026-11-19, kullanıcı: *"oto AI düzeni
 * Wi-Fi'ye ve şarja bağlıyken yapılsın, arka planda da çalışabilsin"*).
 * Sistem şarj + ölçülü olmayan ağ koşulunda başlatır; ayrı bir Flutter
 * motorunda `smart_sort_bg.dart` › `akilliDuzenArkaPlan` koşar, bitince
 * `smartBgDone` der. Uygulama ekrandaysa koşmaz (uygulama kendi turunu yapar,
 * iki izolat aynı depoyu yazmasın).
 */
class SmartBgJob : JobService() {
    private var engine: io.flutter.embedding.engine.FlutterEngine? = null
    private var params: JobParameters? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onStartJob(p: JobParameters?): Boolean {
        if (appVisible()) return false
        params = p
        Extras.activeSmartJob = this
        return runCatching {
            startEngine()
            // Güvenlik: Dart hiç "bitti" demezse sistem sınırından önce kapat.
            main.postDelayed({ finish() }, TimeUnit.MINUTES.toMillis(9))
            true
        }.getOrElse {
            if (Extras.activeSmartJob === this) Extras.activeSmartJob = null
            params = null
            engine?.destroy()
            engine = null
            false
        }
    }

    private fun appVisible(): Boolean = Extras.activityVisible

    internal fun stopFromForeground() {
        main.post { finish() }
    }

    private fun startEngine() {
        engine?.destroy()
        engine = null
        val loader = io.flutter.FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val e = io.flutter.embedding.engine.FlutterEngine(applicationContext)
        try {
            io.flutter.plugin.common.MethodChannel(e.dartExecutor.binaryMessenger, Extras.CHANNEL)
                .setMethodCallHandler { call, result ->
                    val ctx = applicationContext
                    when (call.method) {
                        "isMetered" -> result.success(
                            (ctx.getSystemService(Context.CONNECTIVITY_SERVICE)
                                as android.net.ConnectivityManager).isActiveNetworkMetered
                        )
                        "isCharging" -> result.success(Extras.isCharging(ctx))
                        "unwrapKey" -> result.success(
                            (call.arguments as? ByteArray)?.let { Extras.unwrap(it) }
                        )
                        "smartBg" -> result.success(
                            Extras.scheduleSmartBg(ctx, call.arguments as? Boolean ?: false)
                        )
                        "smartBgDone" -> {
                            result.success(true)
                            main.post { finish() }
                        }
                        else -> result.notImplemented()
                    }
                }
            e.dartExecutor.executeDartEntrypoint(
                io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "package:dosya_okuyucu/services/fm/smart_sort_bg.dart",
                    "akilliDuzenArkaPlan"
                )
            )
            engine = e
        } catch (t: Throwable) {
            e.destroy()
            throw t
        }
    }

    private fun finish() {
        if (Extras.activeSmartJob === this) Extras.activeSmartJob = null
        val p = params
        params = null
        main.removeCallbacksAndMessages(null)
        engine?.destroy()
        engine = null
        if (p != null) {
            runCatching { jobFinished(p, false) }
        }
    }

    override fun onStopJob(p: JobParameters?): Boolean {
        if (Extras.activeSmartJob === this) Extras.activeSmartJob = null
        params = null
        main.removeCallbacksAndMessages(null)
        engine?.destroy()
        engine = null
        return true
    }

    override fun onDestroy() {
        if (Extras.activeSmartJob === this) Extras.activeSmartJob = null
        params = null
        main.removeCallbacksAndMessages(null)
        engine?.destroy()
        engine = null
        super.onDestroy()
    }
}

/** **Depolama + hızlı eylemler** widget'ı: boş yer, doluluk çubuğu, Tara/Ara/Yer aç. */
class StorageWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, manager: AppWidgetManager, ids: IntArray) =
        render(ctx, manager, ids)

    companion object {
        fun render(ctx: Context, manager: AppWidgetManager, ids: IntArray) {
            val strings = Extras.widgetData(ctx).optJSONObject("strings") ?: JSONObject()
            val stat = runCatching { StatFs(Environment.getExternalStorageDirectory().path) }
                .getOrNull()
            val total = stat?.totalBytes ?: 0L
            val free = stat?.availableBytes ?: 0L
            val pct = if (total > 0) ((total - free) * 100 / total).toInt() else 0
            for (id in ids) {
                val views = RemoteViews(ctx.packageName, R.layout.widget_storage)
                views.setTextViewText(
                    R.id.w_title, strings.optString("storage", "Ana bellek")
                )
                views.setTextViewText(
                    R.id.w_free,
                    strings.optString("free", "{v} boş")
                        .replace("{v}", Formatter.formatShortFileSize(ctx, free))
                )
                views.setTextViewText(
                    R.id.w_total,
                    "%$pct · " + Formatter.formatShortFileSize(ctx, total)
                )
                views.setProgressBar(R.id.w_bar, 100, pct, false)
                views.setTextViewText(R.id.w_scan_label, strings.optString("scan", "Tara"))
                views.setTextViewText(R.id.w_search_label, strings.optString("search", "Ara"))
                views.setTextViewText(R.id.w_clean_label, strings.optString("clean", "Yer aç"))
                Extras.linkIntent(ctx, "app:files")?.let {
                    views.setOnClickPendingIntent(R.id.w_root, it)
                }
                Extras.linkIntent(ctx, "app:scan")?.let {
                    views.setOnClickPendingIntent(R.id.w_scan, it)
                }
                Extras.linkIntent(ctx, "app:search")?.let {
                    views.setOnClickPendingIntent(R.id.w_search, it)
                }
                Extras.linkIntent(ctx, "app:clean")?.let {
                    views.setOnClickPendingIntent(R.id.w_clean, it)
                }
                manager.updateAppWidget(id, views)
            }
        }
    }
}

/** **Son dosyalar** widget'ı: son açılan dört dosya, dokununca açılır. */
class RecentWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, manager: AppWidgetManager, ids: IntArray) =
        render(ctx, manager, ids)

    companion object {
        private val ROWS = intArrayOf(R.id.r_1, R.id.r_2, R.id.r_3, R.id.r_4)

        fun render(ctx: Context, manager: AppWidgetManager, ids: IntArray) {
            val data = Extras.widgetData(ctx)
            val strings = data.optJSONObject("strings") ?: JSONObject()
            val recent = data.optJSONArray("recent")
            for (id in ids) {
                val views = RemoteViews(ctx.packageName, R.layout.widget_recent)
                views.setTextViewText(
                    R.id.r_title, strings.optString("recent", "Son açılanlar")
                )
                val count = recent?.length() ?: 0
                views.setViewVisibility(R.id.r_empty, if (count == 0) View.VISIBLE else View.GONE)
                views.setTextViewText(
                    R.id.r_empty, strings.optString("empty", "Henüz açılan dosya yok")
                )
                for ((i, row) in ROWS.withIndex()) {
                    val item = if (i < count) recent!!.optJSONObject(i) else null
                    if (item == null) {
                        views.setViewVisibility(row, View.GONE)
                        continue
                    }
                    views.setViewVisibility(row, View.VISIBLE)
                    views.setTextViewText(row, item.optString("name"))
                    Extras.linkIntent(ctx, "file:" + item.optString("path"))?.let {
                        views.setOnClickPendingIntent(row, it)
                    }
                }
                Extras.linkIntent(ctx, "app:files")?.let {
                    views.setOnClickPendingIntent(R.id.r_title, it)
                }
                manager.updateAppWidget(id, views)
            }
        }
    }
}
