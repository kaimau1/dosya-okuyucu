package com.dosyaokuyucu.dosya_okuyucu

import android.app.AppOpsManager
import android.app.usage.StorageStatsManager
import android.content.Context
import android.content.Intent
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

    private companion object {
        const val CHANNEL = "dosya_okuyucu/app_storage"
    }
}
