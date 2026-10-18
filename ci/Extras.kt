package com.dosyaokuyucu.dosya_okuyucu

import android.app.Activity
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
import android.security.keystore.KeyProperties
import android.text.format.Formatter
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.security.KeyStore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

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
    const val EXTRA_LINK = "dosya_link"
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
        val builder = android.hardware.biometrics.BiometricPrompt.Builder(activity)
            .setTitle(title)
            .setNegativeButton(cancel, executor) { _, _ -> done(false) }
        if (subtitle.isNotEmpty()) builder.setSubtitle(subtitle)
        val prompt = builder.build()
        var answered = false
        prompt.authenticate(
            CancellationSignal(), executor,
            object : android.hardware.biometrics.BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: android.hardware.biometrics.BiometricPrompt.AuthenticationResult?
                ) {
                    if (!answered) { answered = true; done(true) }
                }

                override fun onAuthenticationError(code: Int, msg: CharSequence?) {
                    if (!answered) { answered = true; done(false) }
                }
            }
        )
    }

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
    override fun onStartJob(params: JobParameters?): Boolean {
        Thread {
            runCatching { Extras.runDaily(applicationContext) }
            runCatching { Extras.updateWidgets(applicationContext) }
            jobFinished(params, false)
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean = true
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
