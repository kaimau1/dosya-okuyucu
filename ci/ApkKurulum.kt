package com.dosyaokuyucu.dosya_okuyucu

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipFile

/**
 * **Parçalı paket kurulumu** — `.apks` / `.xapk` / `.apkm` (2026-11-09,
 * kullanıcı bulgusu: *".apks kurulmuyor"*).
 *
 * Kök neden: `.apks` bir ZIP; sistemin paket yükleyicisi (ACTION_VIEW) yalnız
 * TEK `.apk` kurar, ZIP'i tanımaz → "uygulama yok"/"ayrıştırma hatası". Kendi
 * dışa aktardığımız `.apks` (bkz. `ApkExport`) bile bu uygulamada kurulamıyordu.
 *
 * Çözüm: `PackageInstaller` oturumu — ZIP içindeki her `.apk` aynı oturuma
 * yazılır, commit edilir; sistem onay penceresini kendisi gösterir. İmza/sürüm
 * denetimi sistemde; burada yeniden paketleme YOK.
 *
 * ABİ süzgeci: SAI/APKMirror paketleri bütün mimarilerin
 * `split_config.<abi>.apk` parçalarını taşıyabilir; cihazın desteklemediği
 * mimari parçası oturuma girerse kurulum düşer. Desteklenen mimariden en az
 * bir parça varsa ötekiler atlanır. OBB (xapk) kurulmaz — yalnız APK'lar.
 *
 * Sonuç kodu (Dart `NativeExtras.installPackageFile`): `done` · `aborted` ·
 * `need_permission` (bilinmeyen kaynak izni ayarı açıldı) · `no_apk` ·
 * `missing` · `error:<ileti>`.
 */
object ApkKurulum {
    private const val ACTION = "com.dosyaokuyucu.dosya_okuyucu.APK_KURULUM"
    private val main = Handler(Looper.getMainLooper())

    private val abiNames = mapOf(
        "arm64_v8a" to "arm64-v8a",
        "armeabi_v7a" to "armeabi-v7a",
        "armeabi" to "armeabi",
        "x86_64" to "x86_64",
        "x86" to "x86",
    )

    /** `split_config.arm64_v8a.apk` → `arm64-v8a`; mimari parçası değilse null. */
    fun abiOf(entryName: String): String? {
        val base = entryName.substringAfterLast('/').removeSuffix(".apk")
        return abiNames[base.substringAfterLast('.')]
    }

    /** G7.8: oturuma yazılan toplam boyut üst sınırı (4 GB). */
    const val MAX_TOTAL = 4L shl 30

    /** G7.8: ZIP girdi adı güvenli mi (mutlak yol / `..` / ters bölü yok). */
    fun safeName(name: String): Boolean =
        !name.startsWith("/") && !name.contains('\\') &&
            name.split('/').none { it == ".." }

    /** Ana APK girdisi: `base.apk`, yoksa `split_` ile başlamayan ilk parça. */
    fun baseEntry(picked: List<String>): String? =
        picked.firstOrNull { it.substringAfterLast('/') == "base.apk" }
            ?: picked.firstOrNull { !it.substringAfterLast('/').startsWith("split_") }
            ?: picked.firstOrNull()

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString(":") { "%02X".format(it) }

    @Suppress("DEPRECATION")
    private fun signerDigests(info: PackageInfo?): List<String> {
        if (info == null) return emptyList()
        if (Build.VERSION.SDK_INT >= 28) {
            val si = info.signingInfo
            if (si != null) {
                val sigs = if (si.hasMultipleSigners()) si.apkContentsSigners
                else si.signingCertificateHistory
                if (sigs != null && sigs.isNotEmpty()) {
                    // Geçmişte en SON (güncel) imza belirleyici.
                    return if (si.hasMultipleSigners()) sigs.map { sha256(it.toByteArray()) }
                    else listOf(sha256(sigs.last().toByteArray()))
                }
            }
        }
        return info.signatures?.map { sha256(it.toByteArray()) } ?: emptyList()
    }

    @Suppress("DEPRECATION")
    private fun flags(): Int =
        if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES
        else PackageManager.GET_SIGNATURES

    /**
     * **G7.8 kurulum öncesi bilgi**: paket adı, sürüm, imza SHA-256 parmak izi,
     * yüklü sürümle aynı imza mı, bu uygulamanın kendisi mi. Ana APK önbelleğe
     * geçici çıkarılıp `getPackageArchiveInfo` ile okunur, sonra silinir.
     * Hata/okunamazsa `error` alanı dolu döner (Dart yine sorar, bilgisiz).
     */
    fun inspect(ctx: Context, path: String, done: (Map<String, Any?>) -> Unit) {
        Thread {
            val out = HashMap<String, Any?>()
            var tmp: File? = null
            try {
                val file = File(path)
                ZipFile(file).use { zip ->
                    val names = zip.entries().toList().map { it.name }
                    val picked = pickEntries(names, Build.SUPPORTED_ABIS.toList())
                    out["parts"] = picked.size
                    out["unsafe"] = names.any { !safeName(it) }
                    val base = baseEntry(picked) ?: throw IllegalStateException("no_apk")
                    val t = File.createTempFile("inspect", ".apk", ctx.cacheDir)
                    tmp = t
                    zip.getInputStream(zip.getEntry(base)).use { input ->
                        t.outputStream().use { input.copyTo(it, 1 shl 16) }
                    }
                }
                val pm = ctx.packageManager
                val t = tmp!!
                @Suppress("DEPRECATION")
                val info = pm.getPackageArchiveInfo(t.path, flags())
                    ?: throw IllegalStateException("parse")
                info.applicationInfo?.let {
                    it.sourceDir = t.path
                    it.publicSourceDir = t.path
                    out["label"] = try {
                        it.loadLabel(pm).toString()
                    } catch (_: Exception) {
                        null
                    }
                }
                val pkg = info.packageName
                out["package"] = pkg
                out["version"] = info.versionName ?: ""
                out["versionCode"] = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
                else @Suppress("DEPRECATION") info.versionCode.toLong()
                val signers = signerDigests(info)
                out["sha256"] = signers
                out["self"] = pkg == ctx.packageName
                val installed = try {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(pkg, flags())
                } catch (_: PackageManager.NameNotFoundException) {
                    null
                }
                if (installed != null) {
                    out["installedVersion"] = installed.versionName ?: ""
                    val have = signerDigests(installed)
                    out["sameSigner"] = signers.isNotEmpty() && have.isNotEmpty() &&
                        signers.toSet() == have.toSet()
                }
            } catch (e: Exception) {
                out["error"] = e.message ?: e.javaClass.simpleName
            } finally {
                try {
                    tmp?.delete()
                } catch (_: Exception) {
                }
            }
            main.post { done(out) }
        }.start()
    }

    /** Kurulacak ZIP girdileri (mimari süzgeci uygulanmış). */
    fun pickEntries(names: List<String>, supported: List<String>): List<String> {
        val apks = names.filter { it.lowercase().endsWith(".apk") && !it.endsWith("/") }
        val withAbi = apks.filter { abiOf(it) != null }
        if (withAbi.isEmpty()) return apks
        val ok = withAbi.filter { abiOf(it) in supported }
        if (ok.isEmpty()) return apks // süzgeç her şeyi atarsa sisteme bırak
        // Birden çok uygun mimari varsa yalnız EN ÖNCELİKLİ olanı (SUPPORTED_ABIS sırası).
        val best = supported.first { abi -> ok.any { abiOf(it) == abi } }
        return apks.filter { abiOf(it) == null || abiOf(it) == best }
    }

    /**
     * [selfUpdate]: uygulamanın kendi güncellemesi (2026-11-09 oto güncelleme).
     * Android 12+'da `USER_ACTION_NOT_REQUIRED` istenir — sistem izin verirse
     * (bu uygulama kurulumun sahibiyse) onay penceresi ÇIKMADAN kurulur;
     * vermezse yine onay penceresi gelir. Tek `.apk` dosyası (ZIP içinde
     * `.apk` yoksa ve dosyanın kendisi `.apk` ise) olduğu gibi yazılır.
     */
    fun install(
        activity: Activity,
        path: String,
        selfUpdate: Boolean = false,
        done: (String) -> Unit,
    ) {
        val file = File(path)
        if (!file.isFile) {
            done("missing"); return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !activity.packageManager.canRequestPackageInstalls()
        ) {
            try {
                activity.startActivity(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                        .setData(Uri.parse("package:" + activity.packageName))
                )
            } catch (_: Exception) {
            }
            done("need_permission"); return
        }
        val ctx = activity.applicationContext
        // Kurulum süreci kapatır; MY_PACKAGE_REPLACED gelince yeniden açmak
        // için işaret (bkz. [GuncellemeSonrasi]).
        if (selfUpdate) GuncellemeSonrasi.mark(ctx)
        Thread {
            var session: PackageInstaller.Session? = null
            try {
                val installer = ctx.packageManager.packageInstaller
                val params = PackageInstaller.SessionParams(
                    PackageInstaller.SessionParams.MODE_FULL_INSTALL
                )
                if (selfUpdate && Build.VERSION.SDK_INT >= 31) {
                    params.setRequireUserAction(
                        PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED
                    )
                }
                ZipFile(file).use { zip ->
                    val names = zip.entries().toList().map { it.name }
                    val picked = pickEntries(names, Build.SUPPORTED_ABIS.toList())
                    if (picked.isEmpty()) {
                        if (file.name.lowercase().endsWith(".apk") &&
                            names.contains("AndroidManifest.xml")
                        ) {
                            // Tek APK: dosyanın kendisi oturuma yazılır.
                            val id = installer.createSession(params)
                            val s = installer.openSession(id)
                            session = s
                            s.openWrite("base.apk", 0, file.length()).use { out ->
                                file.inputStream().use { it.copyTo(out, 1 shl 16) }
                                s.fsync(out)
                            }
                            main.post { commit(activity, s, id, done) }
                            return@Thread
                        }
                        main.post { done("no_apk") }; return@Thread
                    }
                    // G7.8: yol ayırıcılı/mutlak girdi adı ve aşırı boyut reddi.
                    if (picked.any { !safeName(it) }) {
                        main.post { done("error:unsafe_entry") }; return@Thread
                    }
                    val total = picked.sumOf { zip.getEntry(it).size.coerceAtLeast(0L) }
                    if (total > MAX_TOTAL) {
                        main.post { done("error:too_big") }; return@Thread
                    }
                    val id = installer.createSession(params)
                    val s = installer.openSession(id)
                    session = s
                    picked.forEachIndexed { i, name ->
                        val entry = zip.getEntry(name)
                        val size = if (entry.size >= 0) entry.size else -1L
                        s.openWrite("p$i.apk", 0, size).use { out ->
                            zip.getInputStream(entry).use { it.copyTo(out, 1 shl 16) }
                            s.fsync(out)
                        }
                    }
                    main.post { commit(activity, s, id, done) }
                }
            } catch (e: Exception) {
                try {
                    session?.abandon()
                } catch (_: Exception) {
                }
                main.post { done("error:" + (e.message ?: e.javaClass.simpleName)) }
            }
        }.start()
    }

    private fun commit(
        activity: Activity,
        session: PackageInstaller.Session,
        id: Int,
        done: (String) -> Unit,
    ) {
        val ctx = activity.applicationContext
        val action = "$ACTION.$id"
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                val status = intent.getIntExtra(
                    PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE
                )
                if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
                    @Suppress("DEPRECATION")
                    val confirm = if (Build.VERSION.SDK_INT >= 33) {
                        intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                    } else {
                        intent.getParcelableExtra(Intent.EXTRA_INTENT)
                    }
                    if (confirm != null) {
                        try {
                            activity.startActivity(
                                confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        } catch (e: Exception) {
                            finish(c, this, done, "error:" + (e.message ?: "confirm"))
                        }
                    }
                    return
                }
                val result = when (status) {
                    PackageInstaller.STATUS_SUCCESS -> "done"
                    PackageInstaller.STATUS_FAILURE_ABORTED -> "aborted"
                    else -> "error:" + (
                        intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                            ?: "status $status")
                }
                finish(c, this, done, result)
            }
        }
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= 33) {
            ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            ctx.registerReceiver(receiver, filter)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
        val pi = PendingIntent.getBroadcast(
            ctx, id, Intent(action).setPackage(ctx.packageName), flags
        )
        try {
            session.commit(pi.intentSender)
            session.close()
        } catch (e: Exception) {
            finish(ctx, receiver, done, "error:" + (e.message ?: e.javaClass.simpleName))
        }
    }

    private fun finish(c: Context, r: BroadcastReceiver, done: (String) -> Unit, v: String) {
        try {
            c.applicationContext.unregisterReceiver(r)
        } catch (_: Exception) {
        }
        done(v)
    }
}

/**
 * **Kendi güncellemesinden sonra yeniden aç** (2026-11-10, kullanıcı:
 * *"otomatik güncellendikten sonra uygulama kapanıyor, sonra otomatik geri
 * açılsın"*). Kurulum süreci uygulamayı öldürür; sistem yeni sürümde
 * `MY_PACKAGE_REPLACED` yayınlar. İşaret (son 30 dk'da uygulamanın KENDİ
 * başlattığı güncelleme) varsa ana ekran açılır. Android 10+ arka plandan
 * ekran açmayı yalnız "diğer uygulamaların üstünde göster" izniyle bırakır;
 * izin yoksa "Güncellendi — açmak için dokunun" bildirimi düşer.
 */
class GuncellemeSonrasi : BroadcastReceiver() {
    companion object {
        private const val PREFS = "guncelleme_sonrasi"
        private const val KEY = "self_update_ms"
        private const val CHANNEL = "guncelleme"

        fun mark(c: Context) {
            c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putLong(KEY, System.currentTimeMillis()).apply()
        }
    }

    override fun onReceive(c: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val prefs = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val at = prefs.getLong(KEY, 0L)
        prefs.edit().remove(KEY).apply()
        if (at == 0L || System.currentTimeMillis() - at > 30 * 60 * 1000L) return
        val launch = c.packageManager.getLaunchIntentForPackage(c.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            ?: return
        val canStart = Build.VERSION.SDK_INT < 29 || Settings.canDrawOverlays(c)
        if (canStart) {
            try {
                c.startActivity(launch)
                return
            } catch (_: Exception) {
            }
        }
        notifyDone(c, launch)
    }

    private fun notifyDone(c: Context, launch: Intent) {
        try {
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL, "Uygulama güncellemesi",
                        NotificationManager.IMPORTANCE_HIGH
                    )
                )
            }
            val pi = PendingIntent.getActivity(
                c, 7301, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val b = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(c, CHANNEL)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(c)
            }
            val n = b.setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentTitle("Güncelleme kuruldu")
                .setContentText("Uygulamayı açmak için dokunun")
                .setContentIntent(pi)
                .setAutoCancel(true)
                .build()
            nm.notify(7301, n)
        } catch (_: Exception) {
        }
    }
}
