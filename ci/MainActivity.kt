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
import android.hardware.usb.UsbManager
import android.os.storage.StorageManager
import android.provider.DocumentsContract
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

    /** Dart tarafına olay ITMEK için (native → Dart). */
    private var channel: MethodChannel? = null

    /** SAF klasör seçimi sonucunu bekleyen çağrı. */
    private var pendingPick: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchAction = intent?.action
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // `singleTask`: uygulama açıkken USB takılıp seçilirse yeni intent
        // buradan gelir, `onCreate` bir daha çalışmaz.
        launchAction = intent.action
        // **Dart'a HABER VER (kullanıcı hatası 2026-09-02: "basıyorum tepki
        // vermiyor").** Uygulama zaten ön plandayken seçiciden bizi seçmek
        // yeni bir `resumed` yaşam döngüsü olayı ÜRETMİYOR; Dart tarafı
        // eylemi yalnız `resumed`da sorduğu için hiçbir şey olmuyordu.
        // Şimdi olay itiliyor: sormayı beklemek yerine söylüyoruz.
        if (intent.action == UsbManager.ACTION_USB_DEVICE_ATTACHED) {
            channel?.invokeMethod("usbAttached", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK_TREE) return
        val pending = pendingPick ?: return
        pendingPick = null
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (uri == null) {
            pending.success(null)
            return
        }
        // **Kalıcı izin ŞART.** Alınmazsa izin uygulama kapanınca düşer ve
        // kullanıcı her açılışta klasörü yeniden seçmek zorunda kalır.
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (e: Exception) {
            // Bazı sağlayıcılar kalıcı izin vermiyor; oturum boyu yine çalışır.
        }
        pending.success(uri.toString())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel!!
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

                    // **Android'in KENDİ birim listesi.**
                    "storageVolumes" -> result.success(storageVolumes())

                    // Bağlı birimlerin uygulamaya ait klasöründen türetilen
                    // kökler — `/storage` listelenemese de birimi yakalar.
                    "externalFilesRoots" -> result.success(externalFilesRoots())

                    // **Ham USB aygıt listesi** (teşhis + ham sürücünün girdisi).
                    "usbDevices" -> result.success(usbDevices())

                    // Cihazın USB ana makine (host/OTG) desteği var mı?
                    "usbHostSupported" -> result.success(
                        packageManager.hasSystemFeature(PackageManager.FEATURE_USB_HOST)
                    )

                    // ── SAF (Storage Access Framework) ──────────────────
                    "safPickTree" -> {
                        pendingPick = result
                        try {
                            startActivityForResult(
                                pickTreeIntent(call.argument<String>("volume")),
                                REQ_PICK_TREE
                            )
                        } catch (e: Exception) {
                            pendingPick = null
                            result.success(null)
                        }
                    }

                    "safRoots" -> result.success(safRoots())

                    "safForget" -> {
                        result.success(safForget(call.argument<String>("uri")))
                    }

                    "safList" -> {
                        val uri = call.argument<String>("uri")
                        Thread {
                            val rows = safList(uri)
                            Handler(Looper.getMainLooper()).post { result.success(rows) }
                        }.start()
                    }

                    "safCopyToFile" -> {
                        val uri = call.argument<String>("uri")
                        val dest = call.argument<String>("dest")
                        Thread {
                            val ok = safCopyToFile(uri, dest)
                            Handler(Looper.getMainLooper()).post { result.success(ok) }
                        }.start()
                    }

                    "safCopyFromFile" -> {
                        val parent = call.argument<String>("parent")
                        val src = call.argument<String>("src")
                        val name = call.argument<String>("name")
                        val mime = call.argument<String>("mime")
                        Thread {
                            val uri = safCopyFromFile(parent, src, name, mime)
                            Handler(Looper.getMainLooper()).post { result.success(uri) }
                        }.start()
                    }

                    "safDelete" -> result.success(safDelete(call.argument<String>("uri")))

                    "safMkdir" -> result.success(
                        safMkdir(
                            call.argument<String>("parent"),
                            call.argument<String>("name")
                        )
                    )

                    "safRename" -> result.success(
                        safRename(
                            call.argument<String>("uri"),
                            call.argument<String>("name")
                        )
                    )

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

    /**
     * Cihazdaki depolama birimleri — **Android'in kendi listesi.**
     *
     * **Niye platform kanalı şart oldu (kullanıcı hatası 2026-09-02: USB
     * takılıyken uygulama "Takılı harici bellek yok" diyordu):** Dart tarafı
     * birimleri `/storage` altını LİSTELEYEREK tahmin ediyordu. Bu, SD kartta
     * çalışıyor ama USB OTG'de üreticiye göre değişiyor: kimi ROM `/storage/
     * <UUID>` altına bağlıyor, kimi `/mnt/media_rw/<UUID>` (uygulamaya kapalı),
     * kimi hiç bağlamayıp aygıtı doğrudan uygulamaya veriyor. Tahmin etmek
     * yerine SORMAK gerekiyordu: `StorageManager.getStorageVolumes()` işletim
     * sisteminin gerçek listesidir.
     *
     * Her birim için yol, açıklama, birincil mi, çıkarılabilir mi ve DURUM
     * döner. Durum önemli: "mounted" değilse birim fiziksel olarak takılı ama
     * kullanılamıyordur — kullanıcıya "yok" demek yerine bunu söyleyebiliriz.
     *
     * `getDirectory()` API 30+; daha eski Android'de gizli `getPath()`
     * yansımayla okunur (API 24-29'da başka yol yok, alan adı yıllardır
     * değişmedi). Bulunamazsa yol null döner ve Dart tarafı kendi
     * taramasındaki yolu kullanır.
     */
    private fun storageVolumes(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val sm = try {
            getSystemService(Context.STORAGE_SERVICE) as StorageManager
        } catch (e: Exception) {
            return out
        }
        val volumes = try {
            sm.storageVolumes
        } catch (e: Exception) {
            return out
        }
        for (v in volumes) {
            val uuid = try { v.uuid } catch (e: Exception) { null }
            val path = volumePath(v, uuid)
            out.add(
                mapOf(
                    "path" to path,
                    "description" to try { v.getDescription(this) } catch (e: Exception) { null },
                    "isPrimary" to v.isPrimary,
                    "isRemovable" to v.isRemovable,
                    "state" to try { v.state } catch (e: Exception) { null },
                    "uuid" to uuid,
                    // **Gerçekten okunabiliyor mu?** `state` yalan söyleyebilir
                    // (bkz. `volumePath`); dosya sistemi söyleyemez.
                    "readable" to readableDir(path)
                )
            )
        }
        return out
    }

    /**
     * Bir birimin dosya YOLU — Android'in tek bir cevabına GÜVENİLMEZ.
     *
     * Kullanıcı hatası 2026-09-02 (ekran görüntüsü): başka bir dosya yöneticisi
     * takılı USB belleği ("TYPEC 64", 47,4/62 GB) listeliyordu, biz "Takılı
     * değil" diyorduk. Sebep: `StorageVolume.getDirectory()` AOSP'de
     *
     *     when (state) { MOUNTED, MOUNTED_READ_ONLY -> mPath; else -> null }
     *
     * ve `getState()` birimi UYGULAMAYA GÖRÜNEN listede yolla arayıp bulamazsa
     * `unknown` döner. Yani bağlı bir USB'de bile `directory` null çıkabiliyor
     * — biz de o birimi "bağlanmamış" sayıp eliyorduk.
     *
     * Bu yüzden sırayla: `getDirectory()` → gizli `getPath()`/`getPathFile()`
     * (durum denetimi YOK, ham alanı verir) → `/storage/<uuid>`. Bulunan yol
     * ayrıca dosya sistemine SORULUR ([readableDir]).
     */
    private fun volumePath(v: android.os.storage.StorageVolume, uuid: String?): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                v.directory?.absolutePath?.let { return it }
            } catch (e: Exception) {
                // sıradaki yola düş
            }
        }
        try {
            @Suppress("DiscouragedPrivateApi")
            (v.javaClass.getMethod("getPath").invoke(v) as? String)
                ?.takeIf { it.isNotEmpty() }?.let { return it }
        } catch (e: Exception) {
            // gizli API kaldırılmış olabilir
        }
        try {
            @Suppress("DiscouragedPrivateApi")
            (v.javaClass.getMethod("getPathFile").invoke(v) as? java.io.File)
                ?.absolutePath?.takeIf { it.isNotEmpty() }?.let { return it }
        } catch (e: Exception) {
            // gizli API kaldırılmış olabilir
        }
        if (!uuid.isNullOrEmpty()) {
            val guess = "/storage/$uuid"
            if (readableDir(guess)) return guess
        }
        return null
    }

    /**
     * **Takılı USB aygıtları** — Android'in birim listesinden BAĞIMSIZ kaynak.
     *
     * Kullanıcı 2026-09-02: bellek takılı, başka uygulama görüyor, biz
     * göremiyoruz. `StorageManager` sustuğunda "hiç aygıt yok mu, yoksa aygıt
     * var da Android mi bağlamadı?" sorusunun cevabı YALNIZ burada:
     * `UsbManager` çekirdeğin gördüğü aygıtı listeler, bağlansa da
     * bağlanmasa da.
     *
     * Yığın depolama arayüzü = sınıf 8. Alt sınıf/protokol de veriliyor:
     * ham sürücü ancak protokol 0x50 (Bulk-Only Transport) ile konuşabilir.
     *
     * `serialNumber` BİLEREK okunmuyor: API 29+ üzerinde aygıt izni yokken
     * `SecurityException` fırlatıyor ve teşhis ekranını çökertirdi.
     */
    private fun usbDevices(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val um = try {
            getSystemService(Context.USB_SERVICE) as UsbManager
        } catch (e: Exception) {
            return out
        }
        val devices = try { um.deviceList } catch (e: Exception) { return out }
        for (d in devices.values) {
            val interfaces = ArrayList<Map<String, Any?>>()
            var massStorage = false
            try {
                for (i in 0 until d.interfaceCount) {
                    val itf = d.getInterface(i)
                    if (itf.interfaceClass == 8) massStorage = true
                    interfaces.add(
                        mapOf(
                            "class" to itf.interfaceClass,
                            "subclass" to itf.interfaceSubclass,
                            "protocol" to itf.interfaceProtocol,
                            "endpoints" to itf.endpointCount
                        )
                    )
                }
            } catch (e: Exception) {
                // arayüzler okunamadı — aygıt yine listelensin
            }
            out.add(
                mapOf(
                    "name" to d.deviceName,
                    "vendorId" to d.vendorId,
                    "productId" to d.productId,
                    "deviceClass" to d.deviceClass,
                    "manufacturer" to try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
                            d.manufacturerName else null
                    } catch (e: Exception) { null },
                    "product" to try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
                            d.productName else null
                    } catch (e: Exception) { null },
                    "interfaces" to interfaces,
                    "isMassStorage" to massStorage,
                    "hasPermission" to try { um.hasPermission(d) } catch (e: Exception) { false }
                )
            )
        }
        return out
    }

    /** Yol GERÇEKTEN listelenebiliyor mu? (izin yoksa `listFiles()` null döner) */
    private fun readableDir(path: String?): Boolean {
        if (path.isNullOrEmpty()) return false
        return try {
            val f = java.io.File(path)
            f.isDirectory && f.canRead() && f.listFiles() != null
        } catch (e: Exception) {
            false
        }
    }

    /**
     * **Uygulamaya ait klasörden türetilen birim kökleri.**
     *
     * `getExternalFilesDirs()` BAĞLI her birimde uygulamaya ait bir klasör
     * döndürür (`/storage/1A2B-3C4D/Android/data/<paket>/files`). O klasör
     * uygulamanın kendisinindir: hiçbir izin gerektirmez ve `/storage`
     * listelenemeyen ROM'larda bile gelir. Yolun `/Android/` öncesi birimin
     * KÖKÜDÜR — böylece `StorageManager` sussa da bağlı bir SD/USB'yi
     * yakalıyoruz.
     */
    private fun externalFilesRoots(): List<String> {
        val out = LinkedHashSet<String>()
        val dirs = ArrayList<java.io.File?>()
        try { dirs.addAll(getExternalFilesDirs(null)) } catch (e: Exception) {}
        try { dirs.addAll(externalCacheDirs) } catch (e: Exception) {}
        for (dir in dirs) {
            val path = try { dir?.absolutePath } catch (e: Exception) { null } ?: continue
            val idx = path.indexOf("/Android/")
            if (idx <= 0) continue
            out.add(path.substring(0, idx))
        }
        return out.toList()
    }

    // ── SAF (Storage Access Framework) ──────────────────────────────────
    //
    // **Niye gerekti (kullanıcı 2026-09-02):** USB bellek takılıyken Android
    // onu dosya YOLU olarak vermiyor (bkz. `storageVolumes` notu). Android
    // 11+ üzerinde takılabilir belleğe erişmenin herkese açık yolu SAF'tır:
    // kullanıcı bir kez klasörü seçer, uygulama kalıcı izin alır ve o ağacı
    // `DocumentsContract` üzerinden okuyup yazar.
    //
    // **Sınır — dürüstçe:** SAF ancak Android birimi BAĞLADIYSA (mount) ve
    // sistem belge sağlayıcısına verdiyse çalışır. Android hiç bağlamadıysa
    // seçicide de görünmez; o durumda tek çare aygıtı ham USB olarak sürmek
    // (kendi yığın depolama sürücümüzü yazmak) olurdu — o ayrı ve çok daha
    // büyük bir iş.

    /**
     * Bir ağaç ya da belge URI'sinden **belge** URI'si üretir.
     *
     * `DocumentsContract.createDocument`/`renameDocument` ağaç kökünü değil
     * BELGE URI'sini ister; ağaç kökü verildiğinde çağrı sessizce başarısız
     * olur. Tek yerde çevirmek bu tuzağı kapatıyor.
     *
     * **Niye `DocumentFile` YOK:** o sınıf `androidx.documentfile` paketinde
     * ve yeni bir Gradle bağımlılığı demek. CI `android/` iskeletini her
     * derlemede yeniden ürettiği için oraya eklenen her bağımlılık bakım
     * borcudur (bkz. HAFIZA). `DocumentsContract` çerçevenin kendisinde.
     */
    private fun docUriOf(uri: Uri): Uri {
        return try {
            // Belge URI'siyse kimliği doğrudan verir.
            DocumentsContract.buildDocumentUriUsingTree(
                uri, DocumentsContract.getDocumentId(uri)
            )
        } catch (e: Exception) {
            DocumentsContract.buildDocumentUriUsingTree(
                uri, DocumentsContract.getTreeDocumentId(uri)
            )
        }
    }

    /** Bir belgenin görünen adı (yoksa null). */
    private fun displayNameOf(uri: Uri): String? {
        return try {
            contentResolver.query(
                uri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null, null, null
            )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (e: Exception) {
            null
        }
    }

    /** Kalıcı izin alınmış ağaçlar: uri + görünen ad. */
    /**
     * Klasör seçici intent'i — mümkünse **doğrudan o birimin üstünde** açılır.
     *
     * Kullanıcı hatası 2026-09-02: seçicide takılı USB'yi bulamıyordu.
     * `StorageVolume.createOpenDocumentTreeIntent()` (API 29+) seçiciyi tam o
     * birimin köküne konumlandırır — kullanıcı çekmecede aramak zorunda
     * kalmaz. Birim adı verilmezse (ya da eşleşmezse) sıradan
     * `ACTION_OPEN_DOCUMENT_TREE`ye düşülür; davranış eskisi gibi kalır.
     *
     * [volume] birimin UUID'si ya da yolu olabilir (Dart tarafı hangisini
     * biliyorsa onu yollar).
     */
    private fun pickTreeIntent(volume: String?): Intent {
        val fallback = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        if (!volume.isNullOrEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val sm = getSystemService(Context.STORAGE_SERVICE) as StorageManager
                val match = sm.storageVolumes.firstOrNull { v ->
                    val uuid = try { v.uuid } catch (e: Exception) { null }
                    uuid == volume || volumePath(v, uuid) == volume
                }
                if (match != null) {
                    return match.createOpenDocumentTreeIntent().addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                    )
                }
            } catch (e: Exception) {
                // Seçiciyi konumlandıramadık — sıradan seçici yine açılır.
            }
        }
        return fallback.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
    }

    private fun safRoots(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        try {
            for (perm in contentResolver.persistedUriPermissions) {
                if (!perm.isReadPermission) continue
                val uri = perm.uri
                val name = displayNameOf(docUriOf(uri))
                out.add(
                    mapOf(
                        "uri" to uri.toString(),
                        "name" to (name ?: uri.lastPathSegment ?: "?"),
                        "writable" to perm.isWritePermission
                    )
                )
            }
        } catch (e: Exception) {
            // izin listesi okunamadı — boş dön
        }
        return out
    }

    private fun safForget(uri: String?): Boolean {
        if (uri.isNullOrEmpty()) return false
        return try {
            contentResolver.releasePersistableUriPermission(
                Uri.parse(uri),
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Bir belge (ya da ağaç kökü) altındaki girdiler.
     *
     * `DocumentsContract` ile tek sorgu: `DocumentFile.listFiles()` her girdi
     * için AYRI sorgu yapıyor ve yüzlerce dosyalı bir klasörde saniyeler
     * sürüyor. Sütunları tek seferde çekmek aynı işi bir sorguda bitirir.
     */
    private fun safList(uriString: String?): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (uriString.isNullOrEmpty()) return out
        try {
            val uri = Uri.parse(uriString)
            // Ağaç kökü mü yoksa alt belge mi? İkisinde de çocuk URI'si
            // "ağaç + belge kimliği" ile kurulur.
            val docId = try {
                DocumentsContract.getDocumentId(uri)
            } catch (e: Exception) {
                DocumentsContract.getTreeDocumentId(uri)
            }
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(uri, docId)
            contentResolver.query(
                children,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED
                ),
                null, null, null
            )?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0) ?: continue
                    val mime = c.getString(2) ?: ""
                    out.add(
                        mapOf(
                            "uri" to DocumentsContract.buildDocumentUriUsingTree(uri, id)
                                .toString(),
                            "name" to (c.getString(1) ?: id),
                            "isDir" to (mime == DocumentsContract.Document.MIME_TYPE_DIR),
                            "size" to (if (c.isNull(3)) 0L else c.getLong(3)),
                            "modified" to (if (c.isNull(4)) 0L else c.getLong(4)),
                            "mime" to mime
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Okunamadı — boş liste; Dart tarafı "klasör açılamadı" der.
        }
        return out
    }

    /** SAF belgesini yerel dosyaya kopyalar (aç/indir akışı). */
    private fun safCopyToFile(uriString: String?, dest: String?): Boolean {
        if (uriString.isNullOrEmpty() || dest.isNullOrEmpty()) return false
        return try {
            contentResolver.openInputStream(Uri.parse(uriString))?.use { input ->
                java.io.File(dest).outputStream().use { output ->
                    input.copyTo(output, 64 * 1024)
                }
            } != null
        } catch (e: Exception) {
            false
        }
    }

    /** Yerel dosyayı SAF klasörüne yazar; oluşan belgenin URI'si döner. */
    private fun safCopyFromFile(
        parent: String?,
        src: String?,
        name: String?,
        mime: String?
    ): String? {
        if (parent.isNullOrEmpty() || src.isNullOrEmpty() || name.isNullOrEmpty()) {
            return null
        }
        return try {
            val parentDoc = docUriOf(Uri.parse(parent))
            // Aynı adlı belge varsa ÜSTÜNE yazmıyoruz: SAF yeni bir
            // "ad (1)" üretir ve kullanıcı iki kopya görür. Önce siliyoruz —
            // kopyalama akışının çakışma sorusu Dart tarafında zaten soruldu.
            for (child in safList(parent)) {
                if (child["name"] == name) {
                    safDelete(child["uri"] as? String)
                    break
                }
            }
            val doc = DocumentsContract.createDocument(
                contentResolver,
                parentDoc,
                if (mime.isNullOrEmpty()) "application/octet-stream" else mime,
                name
            ) ?: return null
            contentResolver.openOutputStream(doc)?.use { output ->
                java.io.File(src).inputStream().use { input ->
                    input.copyTo(output, 64 * 1024)
                }
            }
            doc.toString()
        } catch (e: Exception) {
            null
        }
    }

    private fun safDelete(uriString: String?): Boolean {
        if (uriString.isNullOrEmpty()) return false
        return try {
            DocumentsContract.deleteDocument(
                contentResolver, docUriOf(Uri.parse(uriString))
            )
        } catch (e: Exception) {
            false
        }
    }

    private fun safMkdir(parent: String?, name: String?): String? {
        if (parent.isNullOrEmpty() || name.isNullOrEmpty()) return null
        return try {
            DocumentsContract.createDocument(
                contentResolver,
                docUriOf(Uri.parse(parent)),
                DocumentsContract.Document.MIME_TYPE_DIR,
                name
            )?.toString()
        } catch (e: Exception) {
            null
        }
    }

    private fun safRename(uriString: String?, name: String?): String? {
        if (uriString.isNullOrEmpty() || name.isNullOrEmpty()) return null
        return try {
            DocumentsContract.renameDocument(
                contentResolver, docUriOf(Uri.parse(uriString)), name
            )?.toString()
        } catch (e: Exception) {
            null
        }
    }

    private companion object {
        const val CHANNEL = "dosya_okuyucu/app_storage"
        const val REQ_PICK_TREE = 7301
    }
}
