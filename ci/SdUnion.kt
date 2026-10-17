package com.dosyaokuyucu.dosya_okuyucu

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaScannerConnection
import android.os.BatteryManager
import android.os.Build
import android.os.PersistableBundle
import android.text.format.Formatter
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * **SD kartla birleşik depolama — yalnız ŞARJ OLURKEN** (kullanıcı isteği
 * 2026-10-17: *"sadece şarj olurken çalışan SD kartı ile birlik olarak kullan
 * özelliği"*).
 *
 * Android'in kendi "SD kartı dahili depolama olarak biçimlendir" (adoptable
 * storage) seçeneği kartı SİLER, çoğu üretici kaldırdı ve kart çıkınca
 * telefon bozulur. Bunun yerine dosya düzeyinde birleşim: seçilen klasörlerin
 * (Kamera, Resimler, Videolar…) belli bir günden eski dosyaları SD kartta
 * **aynı klasör yoluna** taşınır. Uygulamanın listeleri iki birimi zaten
 * birlikte gösteriyor; galeri uygulamaları da SD karttaki `DCIM/Camera`yı
 * dahilinkiyle aynı albümde toplar. Ana bellek boşalır, kullanıcı için tek
 * bir depolama gibi davranır.
 *
 * ## Niye yerel (Kotlin) ve niye JobScheduler
 * Telefon gece şarja takıldığında uygulama genelde KAPALIDIR; Dart izolatı
 * yoktur. `JobScheduler` + `setRequiresCharging(true)` sistemin kendisine
 * "şarjdayken çalıştır, şarjdan çıkınca durdur" dedirtiyor — pil için en
 * ucuz yol ve izin/ön plan servisi gerektirmiyor. Şarjdan çıkınca sistem
 * [SdUnionJob.onStopJob]'u çağırır; o an kopyalanan dosya YARIM BIRAKILMAZ
 * (bkz. [SdUnionEngine.transfer]).
 *
 * Ayarlar Dart'ta tutulur ve `configure` ile buraya JSON olarak gelir
 * (bildirim metinleri dahil — çeviri tablosu Dart'ta).
 */
object SdUnion {
    const val JOB_ID = 0x5D01
    const val JOB_ID_NOW = 0x5D02
    private const val PREFS = "sd_union"
    private const val KEY_CONFIG = "config"
    private const val KEY_STATUS = "status"
    private const val KEY_PENDING_TMP = "pending_tmp"
    private const val CHANNEL_ID = "sd_union"
    private const val NOTIFY_ID = 0x5D03

    /** Aynı anda tek motor (dönemsel iş + "Şimdi taşı" çakışmasın). */
    val running = AtomicBoolean(false)

    /** Kullanıcı "Durdur" dedi / şarj kesildi. */
    val cancel = AtomicBoolean(false)

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun config(ctx: Context): SdUnionConfig? =
        SdUnionConfig.parse(prefs(ctx).getString(KEY_CONFIG, null))

    /** Dart'tan gelen ayarı saklar ve dönemsel işi kurar/kaldırır. */
    fun configure(ctx: Context, json: String): Boolean {
        val cfg = SdUnionConfig.parse(json) ?: return false
        prefs(ctx).edit().putString(KEY_CONFIG, json).apply()
        return if (cfg.enabled) schedule(ctx) else {
            unschedule(ctx)
            true
        }
    }

    /**
     * Şarjdayken en çok yarım saatte bir koşan dönemsel iş. İş bitecek bir şey
     * bulamazsa saniyeler içinde döner; bulduysa sistemin tanıdığı süre
     * (~10 dk) dolana ya da şarj kesilene dek taşır, kalan bir sonrakine.
     */
    fun schedule(ctx: Context): Boolean {
        val js = ctx.getSystemService(JobScheduler::class.java) ?: return false
        val builder = JobInfo.Builder(JOB_ID, ComponentName(ctx, SdUnionJob::class.java))
            .setRequiresCharging(true)
            .setPeriodic(TimeUnit.MINUTES.toMillis(30))
            .setExtras(PersistableBundle().apply { putString("reason", "charging") })
        return try {
            // Yeniden başlatmada da sürsün (RECEIVE_BOOT_COMPLETED ister).
            js.schedule(builder.setPersisted(true).build()) == JobScheduler.RESULT_SUCCESS
        } catch (e: Exception) {
            try {
                js.schedule(builder.setPersisted(false).build()) == JobScheduler.RESULT_SUCCESS
            } catch (e2: Exception) {
                false
            }
        }
    }

    fun unschedule(ctx: Context) {
        val js = ctx.getSystemService(JobScheduler::class.java) ?: return
        js.cancel(JOB_ID)
    }

    fun isScheduled(ctx: Context): Boolean {
        val js = ctx.getSystemService(JobScheduler::class.java) ?: return false
        return js.allPendingJobs.any { it.id == JOB_ID }
    }

    /**
     * "Şimdi taşı": şarj şartı OLMADAN tek seferlik iş. İş kuyruğuna
     * verilir (uygulama kapansa da sürsün); ilerleme [status] ile okunur.
     */
    fun runNow(ctx: Context): Boolean {
        if (running.get()) return true
        val js = ctx.getSystemService(JobScheduler::class.java) ?: return false
        val info = JobInfo.Builder(JOB_ID_NOW, ComponentName(ctx, SdUnionJob::class.java))
            .setOverrideDeadline(0)
            .setExtras(PersistableBundle().apply { putString("reason", "manual") })
            .build()
        return try {
            js.schedule(info) == JobScheduler.RESULT_SUCCESS
        } catch (e: Exception) {
            false
        }
    }

    fun stop(ctx: Context) {
        cancel.set(true)
        ctx.getSystemService(JobScheduler::class.java)?.cancel(JOB_ID_NOW)
    }

    fun isCharging(ctx: Context): Boolean {
        val battery = ctx.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?: return false
        val status = battery.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        return status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
    }

    /** Son çalışmanın özeti + süren işin ilerlemesi (Dart ekranı okur). */
    fun status(ctx: Context): Map<String, Any?> {
        val raw = prefs(ctx).getString(KEY_STATUS, null)
        val json = try {
            if (raw == null) JSONObject() else JSONObject(raw)
        } catch (e: Exception) {
            JSONObject()
        }
        val out = HashMap<String, Any?>()
        for (key in json.keys()) {
            // JSONObject.NULL kanaldan geçmez (StandardMessageCodec tanımaz).
            val value = json.get(key)
            out[key] = if (value == JSONObject.NULL) null else value
        }
        out["running"] = running.get()
        out["scheduled"] = isScheduled(ctx)
        out["charging"] = isCharging(ctx)
        return out
    }

    internal fun writeStatus(ctx: Context, status: JSONObject) {
        prefs(ctx).edit().putString(KEY_STATUS, status.toString()).apply()
    }

    internal fun readStatus(ctx: Context): JSONObject {
        val raw = prefs(ctx).getString(KEY_STATUS, null) ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            JSONObject()
        }
    }

    internal fun setPendingTmp(ctx: Context, path: String?) {
        prefs(ctx).edit().apply {
            if (path == null) remove(KEY_PENDING_TMP) else putString(KEY_PENDING_TMP, path)
        }.apply()
    }

    internal fun pendingTmp(ctx: Context): String? =
        prefs(ctx).getString(KEY_PENDING_TMP, null)

    /** İş bitince kısa özet bildirimi (yalnız bir şey taşındıysa). */
    internal fun notifyDone(ctx: Context, cfg: SdUnionConfig, moved: Int, bytes: Long) {
        if (!cfg.notify || moved <= 0 || cfg.doneTitle.isEmpty()) return
        try {
            val manager = ctx.getSystemService(NotificationManager::class.java) ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID, cfg.channelName.ifEmpty { cfg.doneTitle },
                        NotificationManager.IMPORTANCE_LOW
                    )
                )
            }
            val body = cfg.doneBody
                .replace("{n}", moved.toString())
                .replace("{size}", Formatter.formatShortFileSize(ctx, bytes))
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(ctx, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                android.app.Notification.Builder(ctx)
            }
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            if (launch != null) {
                builder.setContentIntent(
                    android.app.PendingIntent.getActivity(
                        ctx, NOTIFY_ID, launch,
                        android.app.PendingIntent.FLAG_IMMUTABLE or
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT
                    )
                )
            }
            manager.notify(
                NOTIFY_ID,
                builder
                    .setSmallIcon(ctx.applicationInfo.icon)
                    .setContentTitle(cfg.doneTitle)
                    .setContentText(body)
                    .setAutoCancel(true)
                    .build()
            )
        } catch (e: Exception) {
            // Bildirim izni yoksa sessizce geç; iş yine yapıldı.
        }
    }

    /** Android ≤10'da galeriye haber ver (11+'da FUSE kendisi görüyor). */
    internal fun mediaScan(ctx: Context, paths: List<String>) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R || paths.isEmpty()) return
        try {
            MediaScannerConnection.scanFile(ctx, paths.toTypedArray(), null, null)
        } catch (e: Exception) {
        }
    }
}

/** Dart'ın gönderdiği ayar. */
class SdUnionConfig(
    val enabled: Boolean,
    /** true = taşı (ana bellek boşalır), false = kopyala (yedek). */
    val move: Boolean,
    val primary: String,
    val sdPath: String,
    val folders: List<String>,
    val minAgeDays: Int,
    val keepFreeBytes: Long,
    val notify: Boolean,
    val doneTitle: String,
    val doneBody: String,
    val channelName: String,
) {
    companion object {
        fun parse(json: String?): SdUnionConfig? {
            if (json.isNullOrEmpty()) return null
            return try {
                val o = JSONObject(json)
                val folders = ArrayList<String>()
                val arr: JSONArray = o.optJSONArray("folders") ?: JSONArray()
                for (i in 0 until arr.length()) {
                    val f = arr.optString(i).trim('/')
                    if (f.isNotEmpty()) folders.add(f)
                }
                SdUnionConfig(
                    enabled = o.optBoolean("enabled", false),
                    move = o.optString("mode", "move") != "copy",
                    primary = o.optString("primary", "").trimEnd('/'),
                    sdPath = o.optString("sdPath", "").trimEnd('/'),
                    folders = folders,
                    minAgeDays = o.optInt("minAgeDays", 30).coerceAtLeast(0),
                    keepFreeBytes = o.optLong("keepFreeMb", 1024L).coerceAtLeast(0L) * 1024L * 1024L,
                    notify = o.optBoolean("notify", true),
                    doneTitle = o.optString("doneTitle", ""),
                    doneBody = o.optString("doneBody", ""),
                    channelName = o.optString("channelName", ""),
                )
            } catch (e: Exception) {
                null
            }
        }
    }
}

/**
 * Hangi dosya taşınır, nereye — SAF kurallar (yalnız `java.io`; birim
 * denetimi JVM'de koşabilir).
 */
object SdUnionRules {
    /** Yazılmakta olabilecek dosyaya dokunma (kamera henüz kaydediyor). */
    const val SETTLE_MS = 10L * 60L * 1000L

    const val TMP_SUFFIX = ".dosyaokuyucu-tasiniyor"

    /**
     * Sohbet uygulamalarının medyası taşınmaz: WhatsApp/Telegram sohbetteki
     * dosyayı YOLUYLA tutar, yer değişince balon "dosya yok" olur (aynı kural
     * Dart'ta `ChatMediaGuard`).
     */
    fun isChatPath(path: String): Boolean {
        for (segment in path.lowercase().split('/')) {
            if (segment.isEmpty()) continue
            if (segment.contains("whatsapp") || segment.contains("telegram") ||
                segment == "signal" || segment == "org.thoughtcrime.securesms" ||
                segment == "viber" || segment == "com.viber.voip" ||
                segment == "micromsg" || segment == "com.tencent.mm"
            ) return true
        }
        return false
    }

    /**
     * Gizli adlar (`.thumbnails`, `.nomedia`, Android 11'in `.trashed-…`/
     * `.pending-…` dosyaları, bizim gizli kasamız ve geçici dosyalarımız)
     * hiçbir zaman taşınmaz. `Android/` (uygulama verisi) zaten kapsam dışı.
     */
    fun isHiddenName(name: String): Boolean = name.startsWith(".")

    fun isEligibleFile(
        name: String,
        relPath: String,
        lengthBytes: Long,
        lastModifiedMs: Long,
        nowMs: Long,
        minAgeDays: Int,
    ): Boolean {
        if (lengthBytes <= 0L) return false
        if (isHiddenName(name) || isChatPath(relPath)) return false
        val age = nowMs - lastModifiedMs
        if (age < SETTLE_MS) return false
        return age >= TimeUnit.DAYS.toMillis(minAgeDays.toLong())
    }

    /** Klasöre girilir mi? (gizli, sohbet ve `Android/` ağaçları hayır) */
    fun isEligibleDir(name: String, relPath: String): Boolean {
        if (isHiddenName(name) || isChatPath(relPath)) return false
        return !relPath.equals("Android", ignoreCase = true) &&
            !relPath.startsWith("Android/", ignoreCase = true)
    }

    /** `ad.jpg` doluysa `ad (1).jpg`, `ad (2).jpg`… */
    fun uniqueDest(dest: File): File {
        if (!dest.exists()) return dest
        val name = dest.name
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var i = 1
        while (true) {
            val candidate = File(dest.parentFile, "$base ($i)$ext")
            if (!candidate.exists()) return candidate
            i++
        }
    }

    /**
     * İki dosya aynı mı? Boy + baştan ve sondan 64 KB. Tam özet (SHA) her
     * çalışmada binlerce fotoğrafı baştan okutur; aynı boyda ve aynı uçlarda
     * farklı fotoğraf pratikte yok (JPEG'in başında EXIF zamanı, sonunda
     * sıkıştırılmış veri durur).
     */
    fun sameContent(a: File, b: File): Boolean {
        val len = a.length()
        if (len != b.length()) return false
        val chunk = 64 * 1024
        return try {
            FileInputStream(a).use { ia ->
                FileInputStream(b).use { ib ->
                    if (!sameRange(ia, ib, 0L, minOf(chunk.toLong(), len))) return false
                    val tail = maxOf(0L, len - chunk)
                    if (tail <= 0L) return true
                    sameRange(ia, ib, tail, len - tail)
                }
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun sameRange(a: FileInputStream, b: FileInputStream, offset: Long, count: Long): Boolean {
        val bufA = ByteArray(count.toInt())
        val bufB = ByteArray(count.toInt())
        a.channel.position(offset)
        b.channel.position(offset)
        if (readFully(a, bufA) != count.toInt() || readFully(b, bufB) != count.toInt()) return false
        return bufA.contentEquals(bufB)
    }

    private fun readFully(input: FileInputStream, buf: ByteArray): Int {
        var read = 0
        while (read < buf.size) {
            val n = input.read(buf, read, buf.size - read)
            if (n < 0) break
            read += n
        }
        return read
    }
}

/** Bir çalışmanın sonucu. */
class SdUnionResult {
    var moved = 0
    var bytes = 0L
    var skipped = 0
    var failed = 0
    /** null = tamam; aksi hâlde `sd_missing` · `sd_readonly` · `sd_full` · `stopped`. */
    var error: String? = null
    val scanned = ArrayList<String>()
}

/**
 * Taşıma motoru. Android'e yalnız [onProgress]/[onTmp] geri çağrılarıyla
 * bağlı; dosya işi `java.io` ile.
 */
class SdUnionEngine(
    private val cfg: SdUnionConfig,
    private val cancelled: AtomicBoolean,
    private val nowMs: Long = System.currentTimeMillis(),
    private val onProgress: (SdUnionResult) -> Unit = {},
    private val onTmp: (String?) -> Unit = {},
) {
    fun run(): SdUnionResult {
        val result = SdUnionResult()
        val sd = File(cfg.sdPath)
        if (cfg.sdPath.isEmpty() || !sd.isDirectory || !sd.canRead()) {
            result.error = "sd_missing"
            return result
        }
        if (!probeWritable(sd)) {
            result.error = "sd_readonly"
            return result
        }
        val primary = File(cfg.primary)
        for (folder in cfg.folders) {
            if (cancelled.get() || result.error != null) break
            val root = File(primary, folder)
            if (!root.isDirectory || !SdUnionRules.isEligibleDir(root.name, folder)) continue
            walk(root, folder, sd, result)
        }
        if (cancelled.get() && result.error == null) result.error = "stopped"
        return result
    }

    private fun probeWritable(sd: File): Boolean = try {
        val probe = File(sd, ".dosyaokuyucu_write_test")
        FileOutputStream(probe).use { it.write(0) }
        probe.delete()
        true
    } catch (e: Exception) {
        false
    }

    private fun walk(dir: File, rel: String, sd: File, result: SdUnionResult) {
        val stack = ArrayDeque<Pair<File, String>>()
        stack.addLast(dir to rel)
        while (stack.isNotEmpty()) {
            if (cancelled.get() || result.error != null) return
            val (current, currentRel) = stack.removeLast()
            val children = current.listFiles() ?: continue
            for (child in children) {
                if (cancelled.get() || result.error != null) return
                val childRel = "$currentRel/${child.name}"
                if (child.isDirectory) {
                    if (SdUnionRules.isEligibleDir(child.name, childRel)) {
                        stack.addLast(child to childRel)
                    }
                    continue
                }
                if (!SdUnionRules.isEligibleFile(
                        child.name, childRel, child.length(), child.lastModified(),
                        nowMs, cfg.minAgeDays
                    )
                ) continue
                transfer(child, File(sd, childRel), sd, result)
            }
        }
    }

    /**
     * Tek dosya — **bölünmez**: önce hedef klasörde gizli geçici dosyaya
     * kopyalanır, boy doğrulanır, `rename` ile yerine konur, SONRA kaynak
     * silinir. Şarj kesilip iş durdurulursa ya da süreç ölürse geriye ya
     * eksiksiz iki kopya ya da yalnız özgün kalır; asla yarım dosya.
     */
    internal fun transfer(source: File, wanted: File, sd: File, result: SdUnionResult) {
        var dest = wanted
        if (dest.exists()) {
            if (SdUnionRules.sameContent(source, dest)) {
                // Önceki bir çalışmada kopyalanmış (ya da silme aşamasında
                // kesilmiş): kopyalama kipinde iş yok, taşımada kaynağı sil.
                if (cfg.move && source.delete()) {
                    result.moved++
                    result.bytes += dest.length()
                    result.scanned.add(source.path)
                } else {
                    result.skipped++
                }
                return
            }
            // Yedek kipinde kartın kopyası ESKİ hâldir → yerine yeni gelir.
            // Taşımada iki ayrı dosyadır → yeni ad.
            if (cfg.move || source.lastModified() <= dest.lastModified()) {
                if (!cfg.move) {
                    result.skipped++
                    return
                }
                dest = SdUnionRules.uniqueDest(dest)
            }
        }
        val need = source.length()
        if (sd.usableSpace - need < cfg.keepFreeBytes) {
            result.error = "sd_full"
            return
        }
        val parent = dest.parentFile ?: return
        if (!parent.isDirectory && !parent.mkdirs()) {
            result.failed++
            return
        }
        val tmp = File(parent, "." + dest.name + SdUnionRules.TMP_SUFFIX)
        onTmp(tmp.path)
        try {
            FileInputStream(source).use { input ->
                FileOutputStream(tmp).use { output ->
                    val buf = ByteArray(1 shl 20)
                    while (true) {
                        if (cancelled.get()) throw InterruptedException()
                        val n = input.read(buf)
                        if (n < 0) break
                        output.write(buf, 0, n)
                    }
                    output.fd.sync()
                }
            }
            if (tmp.length() != need) throw IllegalStateException("boy tutmadı")
            if (dest.exists() && !cfg.move) dest.delete() // yedeğin eski hâli
            if (!tmp.renameTo(dest)) throw IllegalStateException("rename")
        } catch (e: InterruptedException) {
            tmp.delete()
            onTmp(null)
            return
        } catch (e: Exception) {
            tmp.delete()
            onTmp(null)
            result.failed++
            return
        }
        onTmp(null)
        dest.setLastModified(source.lastModified())
        if (cfg.move) {
            // Silinemezse (salt okunur kaynak) iki kopya kalır — kayıp değil.
            if (!source.delete()) result.failed++
            result.scanned.add(source.path)
        }
        result.scanned.add(dest.path)
        result.moved++
        result.bytes += need
        if (result.moved % 25 == 0) onProgress(result)
    }
}

/** Sistemin şarjdayken (ya da "Şimdi taşı"da) çağırdığı iş. */
class SdUnionJob : JobService() {
    @Volatile
    private var worker: Thread? = null

    override fun onStartJob(params: JobParameters): Boolean {
        val ctx = applicationContext
        val cfg = SdUnion.config(ctx)
        val reason = params.extras.getString("reason") ?: "charging"
        if (cfg == null || (!cfg.enabled && reason != "manual") ||
            !SdUnion.running.compareAndSet(false, true)
        ) {
            return false
        }
        SdUnion.cancel.set(false)
        worker = Thread {
            try {
                // Önceki çalışmadan (süreç öldürüldüyse) kalan yarım geçici dosya.
                SdUnion.pendingTmp(ctx)?.let { File(it).delete() }
                SdUnion.setPendingTmp(ctx, null)
                val started = System.currentTimeMillis()
                val previous = SdUnion.readStatus(ctx)
                fun save(r: SdUnionResult, done: Boolean) {
                    val status = JSONObject()
                    status.put("lastRun", started)
                    status.put("reason", reason)
                    status.put("lastMoved", r.moved)
                    status.put("lastBytes", r.bytes)
                    status.put("lastFailed", r.failed)
                    status.put("lastError", r.error ?: JSONObject.NULL)
                    status.put("done", done)
                    val totalMoved = previous.optLong("totalMoved", 0L) + if (done) r.moved else 0
                    val totalBytes = previous.optLong("totalBytes", 0L) + if (done) r.bytes else 0L
                    status.put("totalMoved", totalMoved)
                    status.put("totalBytes", totalBytes)
                    SdUnion.writeStatus(ctx, status)
                }
                val engine = SdUnionEngine(
                    cfg, SdUnion.cancel,
                    onProgress = { r ->
                        save(r, false)
                        SdUnion.mediaScan(ctx, r.scanned.toList())
                        r.scanned.clear()
                    },
                    onTmp = { SdUnion.setPendingTmp(ctx, it) },
                )
                val result = engine.run()
                SdUnion.mediaScan(ctx, result.scanned.toList())
                save(result, true)
                SdUnion.notifyDone(ctx, cfg, result.moved, result.bytes)
            } catch (e: Exception) {
                // Motor hatası işi düşürmesin; durum bir sonraki koşuda yazılır.
            } finally {
                SdUnion.running.set(false)
                jobFinished(params, false)
            }
        }.apply {
            name = "sd-union"
            priority = Thread.MIN_PRIORITY
            start()
        }
        return true
    }

    /** Şarj kesildi / sistem süreyi doldurdu / kullanıcı durdurdu. */
    override fun onStopJob(params: JobParameters): Boolean {
        SdUnion.cancel.set(true)
        // Dönemsel iş zaten yeniden kurulur; tek seferlikte tekrar yok.
        return false
    }
}
