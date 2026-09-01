package com.dosyaokuyucu.dosya_okuyucu

import android.app.AppOpsManager
import android.app.usage.StorageStatsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.storage.StorageManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Uygulamanın Android tarafı.
 *
 * `flutter create` bu dosyayı her CI derlemesinde YENİDEN ÜRETİYOR; elle
 * bakımlı sürüm `ci/MainActivity.kt`te durur ve iş akışı onu manifest gibi
 * üzerine kopyalar (bkz. .github/workflows/build-apk.yml). Buraya bir şey
 * eklerken `ci/` altındaki dosyayı değiştirin, üretilen dosyayı değil.
 *
 * **Neden platform kanalı gerekti:** yüklü uygulamaların KAPLADIĞI ALAN
 * (`StorageStatsManager`) Dart tarafından okunamıyor — `installed_apps`
 * eklentisi ad/sürüm/simge veriyor ama boyut vermiyor, `df` de uygulama
 * başına kırılım bilmiyor. Diğer dosya yöneticilerinin "Uygulamalar 63 GB"
 * kartının kaynağı bu API.
 */
class MainActivity : FlutterActivity() {

    /**
     * Uygulamayı BAŞLATAN intent'in eylemi — Dart tarafı bir kez okuyup
     * temizler (bkz. `launchAction` kanal yöntemi).
     *
     * **Niye gerekli (kullanıcı isteği 2026-09-01):** USB bellek takılınca
     * Android "hangi uygulamayla açayım?" diye soruyor ve kullanıcı bizi
     * seçince uygulama `USB_DEVICE_ATTACHED` eylemiyle açılıyor. O eylemin
     * verisi (URI) YOK, dolayısıyla `receive_sharing_intent` hiçbir şey
     * getirmiyor ve uygulama sıradan bir açılış gibi panoya düşüyordu.
     * Bu köprü sayesinde Dart tarafı "USB yüzünden açıldım" diyebiliyor ve
     * doğrudan takılan belleği açıyor.
     */
    private var launchAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchAction = intent?.action
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // `singleTask`: uygulama açıkken USB takılıp seçilirse yeni intent
        // buradan gelir, `onCreate` bir daha çalışmaz.
        launchAction = intent.action
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())

                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(true)
                    }

                    "openAppStorageSettings" -> {
                        val pkg = call.argument<String>("package")
                        result.success(openAppStorageSettings(pkg))
                    }

                    // Ağır iş: paket başına binder çağrısı. 200+ uygulamalı bir
                    // telefonda saniyeler sürüyor → arka izlekte koşturulur,
                    // sonuç ana izlekte döner (MethodChannel şartı).
                    "appSizes" -> {
                        val packages = call.argument<List<String>>("packages")
                        Thread {
                            val sizes = appSizes(packages)
                            Handler(Looper.getMainLooper()).post {
                                result.success(sizes)
                            }
                        }.start()
                    }

                    // Son AÇILMA zamanı. Ağır olabilir (yüzlerce paket) →
                    // arka izlek.
                    "lastUsed" -> {
                        val days = call.argument<Int>("days") ?: 730
                        Thread {
                            val map = lastUsed(days)
                            Handler(Looper.getMainLooper()).post {
                                result.success(map)
                            }
                        }.start()
                    }

                    // Google Drive kurulumu: Google, hesap girişini paket adı +
                    // imza SHA-1 ikilisi Cloud'da kayıtlıysa veriyor. Kayıt için
                    // gereken SHA-1'i kullanıcıya UYGULAMANIN İÇİNDE göstermek
                    // "hangi APK'yı kurduysa ONUN imzası" garantisi verir —
                    // belge/CI logundaki değer eski bir anahtara ait olabilir.
                    "appSignatureSha1" -> result.success(appSignatureSha1())

                    // Kurulu bir uygulamanın APK dosyalarının YOLU — "APK
                    // olarak paylaş" akışının tek native ihtiyacı.
                    "apkPaths" -> result.success(apkPaths(call.argument<String>("package")))

                    // Uygulamayı başlatan intent eylemi; okununca TEMİZLENİR
                    // (aynı açılış iki kez "USB takıldı" saymasın).
                    "launchAction" -> {
                        val action = launchAction
                        launchAction = null
                        result.success(action)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * "Kullanım erişimi" özel izni verilmiş mi?
     *
     * Bu izin hem son kullanım tarihini hem de uygulama boyutunu açıyor.
     * `AppOpsManager` üzerinden sorulur: normal izin API'si bunu bilmiyor.
     */
    private fun hasUsageAccess(): Boolean {
        return try {
            val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ops.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                ops.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun openUsageAccessSettings() {
        try {
            startActivity(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (e: Exception) {
            // Bazı ROM'larda bu ekran yok — genel ayarlara düş.
            try {
                startActivity(
                    Intent(Settings.ACTION_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (e2: Exception) {
                // yapacak bir şey yok
            }
        }
    }

    /**
     * Uygulamanın **depolama / önbellek temizleme** sayfasını açar.
     *
     * Alt sayfaya doğrudan giden herkese açık bir API YOK; Ayarlar'ın
     * `:settings:fragment_args_key` eklentisi çoğu ROM'da (AOSP, MIUI, One UI)
     * doğrudan "Depolama ve önbellek" bölümüne indiriyor. Tanımayan bir ROM'da
     * ekstra yok sayılır ve uygulama bilgisi sayfası açılır — tek dokunuş
     * uzakta, yine de doğru yer.
     */
    private fun openAppStorageSettings(pkg: String?): Boolean {
        if (pkg.isNullOrEmpty()) return false
        return try {
            val args = Bundle()
            args.putString(":settings:fragment_args_key", "storage_settings")
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", pkg, null))
                .putExtra(":settings:fragment_args_key", "storage_settings")
                .putExtra(":settings:show_fragment_args", args)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Paket → **son açılma zamanı** (epoch ms). Hiç açılmamış / veri yoksa
     * pakete hiç yer verilmez.
     *
     * **Niçin platform kanalı (kullanıcı hatası 2026-08-28: "açtığım birçok
     * şey 'hiç açılmadı' görünüyor"):** `app_usage` eklentisi `lastForeground`
     * diye `UsageStats.getLastTimeForegroundServiceUsed()` döndürüyor — bu
     * "son açılma" DEĞİL, uygulamanın en son ne zaman **ön plan servisi**
     * çalıştırdığı. WhatsApp/Telegram/Termux servis çalıştırdığı için doğru
     * görünüyordu; Hepsiburada, Çeviri, Copilot gibi servis çalıştırmayan
     * uygulamalar 0 dönüyor ve listede "hiç açılmadı" yazıyordu. Doğru alan
     * `getLastTimeUsed()`; Android 10+ ise `getLastTimeVisible()` ile de
     * karşılaştırılır (ekranda görünme, ön plana gelmenin daha dar tanımı).
     *
     * `queryAndAggregateUsageStats` pencere içindeki kovaları paket başına
     * BİRLEŞTİRİR; `getLastTimeUsed` birleştirilmiş değerin en büyüğüdür.
     * Pencere varsayılan 730 gün: Android kullanım verisini bundan uzun
     * tutmuyor, daha geniş istemek boşuna.
     */
    private fun lastUsed(days: Int): Map<String, Long> {
        val out = HashMap<String, Long>()
        if (!hasUsageAccess()) return out
        val usm = try {
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        } catch (e: Exception) {
            return out
        }
        val end = System.currentTimeMillis()
        val day = 24L * 60L * 60L * 1000L
        val floor = end - days.toLong() * day

        fun keep(pkg: String?, time: Long) {
            if (pkg.isNullOrEmpty() || time <= floor) return
            if (time > (out[pkg] ?: 0L)) out[pkg] = time
        }

        fun merge(stats: Collection<UsageStats>?) {
            if (stats == null) return
            for (s in stats) {
                var last = s.lastTimeUsed
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    last = maxOf(last, s.lastTimeVisible)
                }
                keep(s.packageName, last)
            }
        }

        // **BİRDEN ÇOK KOVA TÜRÜ TARANIR — 2026-08-29 düzeltmesi.**
        // İlk sürüm yalnız `queryAndAggregateUsageStats(730 gün)` soruyordu;
        // o çağrı `INTERVAL_BEST` seçiyor ve 2 yıllık bir aralıkta YILLIK
        // kovaya düşüyor. Yıllık kova birçok ROM'da (özellikle MIUI) budanmış
        // geliyor: kullanıcının haftalar önce açtığı Termux, Copilot, getir
        // gibi uygulamalar sonuçta HİÇ yer almıyor ve listede yine "hiç
        // açılmadı" yazıyordu. Kovaların geriye dönük derinliği farklı
        // (günlük ~7 gün, haftalık ~4 hafta, aylık ~6 ay, yıllık ~2 yıl);
        // hepsi ayrı ayrı sorulup **en büyük zaman damgası** alınıyor.
        val windows = listOf(
            UsageStatsManager.INTERVAL_DAILY to 8L,
            UsageStatsManager.INTERVAL_WEEKLY to 35L,
            UsageStatsManager.INTERVAL_MONTHLY to 200L,
            UsageStatsManager.INTERVAL_YEARLY to days.toLong(),
            UsageStatsManager.INTERVAL_BEST to days.toLong(),
        )
        for ((interval, span) in windows) {
            try {
                merge(usm.queryUsageStats(interval, end - span * day, end))
            } catch (e: Exception) {
                // Bu kova bu ROM'da yoksa diğerleri yine çalışır.
            }
        }
        try {
            merge(usm.queryAndAggregateUsageStats(floor, end).values)
        } catch (e: Exception) {
        }

        // **Olay günlüğü — son günlerin EN GÜVENİLİR kaynağı.** Kova
        // istatistikleri gün sonunda yazılıyor; bugün açılan bir uygulama
        // kovalarda henüz görünmeyebiliyor. `queryEvents` ham olay akışı
        // olduğu için "bugün" ve "1 gün önce" ancak burada doğru çıkıyor.
        try {
            val events = usm.queryEvents(end - 8L * day, end)
            val event = UsageEvents.Event()
            val foreground = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                UsageEvents.Event.ACTIVITY_RESUMED
            } else {
                @Suppress("DEPRECATION")
                UsageEvents.Event.MOVE_TO_FOREGROUND
            }
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == foreground) {
                    keep(event.packageName, event.timeStamp)
                }
            }
        } catch (e: Exception) {
        }
        return out
    }

    /**
     * Paket → [uygulama, veri, önbellek] bayt.
     *
     * `packages` boş/atlanmışsa hiçbir şey dönmez: paket listesini Dart tarafı
     * (`installed_apps`) zaten biliyor, burada ikinci kez toplamaya gerek yok.
     * İzin yoksa ya da paket okunamıyorsa o paket sonuçta HİÇ yer almaz —
     * arayüz "boyut bilinmiyor" diye gösterir, sıfır yazmaz.
     */
    private fun appSizes(packages: List<String>?): Map<String, List<Long>> {
        val out = HashMap<String, List<Long>>()
        if (packages.isNullOrEmpty()) return out
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return out
        if (!hasUsageAccess()) return out
        val stats = try {
            getSystemService(Context.STORAGE_STATS_SERVICE) as StorageStatsManager
        } catch (e: Exception) {
            return out
        }
        val user = Process.myUserHandle()
        for (pkg in packages) {
            try {
                val s = stats.queryStatsForPackage(
                    StorageManager.UUID_DEFAULT, pkg, user
                )
                out[pkg] = listOf(s.appBytes, s.dataBytes, s.cacheBytes)
            } catch (e: Exception) {
                // Kaldırılmış / başka kullanıcıya ait / okunamayan paket: atla.
            }
        }
        return out
    }

    /**
     * Bu APK'nın imza sertifikasının SHA-1'i, düz onaltılık (40 karakter).
     *
     * Google Cloud'a "Android OAuth istemcisi" kaydı bu değeri ister; APK'yı
     * kimin/nasıl imzaladığından bağımsız olarak her zaman kurulu APK'nın
     * GERÇEK imzasını verir. Biçimleme (aa:bb:…) Dart tarafında — saf fonksiyon
     * olarak test edilebilsin diye.
     */
    private fun appSignatureSha1(): String? {
        return try {
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName, PackageManager.GET_SIGNING_CERTIFICATES
                ).signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName, PackageManager.GET_SIGNATURES
                ).signatures
            }
            val first = signatures?.firstOrNull() ?: return null
            java.security.MessageDigest.getInstance("SHA-1")
                .digest(first.toByteArray())
                .joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Kurulu paketin APK dosyaları: temel APK + (varsa) bölünmüş parçalar.
     *
     * **Niye platform kanalı:** APK'nın diskteki yeri yalnız `PackageManager`
     * tarafından biliniyor (`ApplicationInfo.sourceDir`). Yol
     * `/data/app/~~<rastgele>/<paket>-<rastgele>/base.apk` biçiminde ve
     * içindeki iki rastgele parça yüzünden TAHMİN EDİLEMEZ; üstelik Android
     * 11'den beri `/data/app` listelenemiyor. Dart tarafı yolu öğrendikten
     * sonra dosyayı normal okuyabiliyor (APK'lar 644, herkes okuyabilir) —
     * yani kopyalama/paylaşma işi native tarafta değil, Dart'ta.
     *
     * **`splitSourceDirs` neden döndürülüyor:** Play'den kurulan çoğu
     * uygulama App Bundle'dır; cihazda `base.apk` + `split_config.arm64_v8a`
     * + `split_config.xxhdpi` … olarak durur. Yalnız `base.apk`ı paylaşmak
     * karşı tarafta "uygulama yüklenmedi" demek olabilir. Parçaları da
     * döndürüyoruz ki Dart tarafı kullanıcıya DOĞRUSUNU söyleyebilsin
     * (bkz. `services/fm/apk_export.dart`).
     *
     * Paket yoksa / okunamıyorsa `null` — arayüz "APK bulunamadı" der,
     * uydurma bir yol denemez.
     */
    private fun apkPaths(pkg: String?): Map<String, Any?>? {
        if (pkg.isNullOrEmpty()) return null
        return try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            val source = info.sourceDir ?: return null
            val splits = info.splitSourceDirs?.filterNotNull() ?: emptyList()
            val version = try {
                packageManager.getPackageInfo(pkg, 0).versionName ?: ""
            } catch (e: Exception) {
                ""
            }
            mapOf(
                "source" to source,
                "splits" to splits,
                "label" to packageManager.getApplicationLabel(info).toString(),
                "versionName" to version
            )
        } catch (e: Exception) {
            null
        }
    }

    private companion object {
        const val CHANNEL = "dosya_okuyucu/app_storage"
    }
}
