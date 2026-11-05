package com.dosyaokuyucu.dosya_okuyucu

import android.app.Activity
import android.content.Intent
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * **Belge tarayıcı v2** (Faz 35 / adım 0, bayrak `scan_engine_v2`) —
 * `lib/services/document_scanner.dart`taki `DocScanNative`in Kotlin yüzü.
 * Kanal `dosya/docscan`, tek iş:
 *
 * **start** — Google ML Kit `GmsDocumentScanner` (Play Hizmetleri): canlı kenar,
 * otomatik çekim, parmak/gölge/leke silme, otomatik döndürme, galeri içe aktarma.
 * Arayüz + model Play Hizmetleri'nden gelir (APK'ya ~0 MB, kamera izni gerekmez).
 * Dönüş: sayfa JPEG yolları (+ varsa Google'ın ürettiği PDF yolu). Play
 * Hizmetleri yoksa/başarısızsa `unavailable` hatası döner → Dart eski yedek akışa düşer.
 *
 * Ağır iş yok: sonuç URI'leri uygulama önbelleğine akışla kopyalanır (Dispatchers
 * yerine ayrı iş parçacığı — ana iş parçacığı bloklanmaz).
 */
class DocScan(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "dosya/docscan"
        const val REQ_SCAN = 7351
    }

    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(
                call.argument<Int>("maxPages") ?: 30,
                call.argument<Boolean>("gallery") != false,
                call.argument<String>("mode") ?: "full",
                result,
            )
            else -> result.notImplemented()
        }
    }

    private fun start(maxPages: Int, gallery: Boolean, mode: String, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Tarama zaten açık", null)
            return
        }
        val scanMode = when (mode) {
            "base" -> GmsDocumentScannerOptions.SCANNER_MODE_BASE
            "filter" -> GmsDocumentScannerOptions.SCANNER_MODE_BASE_WITH_FILTER
            else -> GmsDocumentScannerOptions.SCANNER_MODE_FULL
        }
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(gallery)
            .setPageLimit(maxPages.coerceIn(1, 100))
            .setResultFormats(
                GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                GmsDocumentScannerOptions.RESULT_FORMAT_PDF,
            )
            .setScannerMode(scanMode)
            .build()
        pending = result
        GmsDocumentScanning.getClient(options)
            .getStartScanIntent(activity)
            .addOnSuccessListener { sender ->
                try {
                    activity.startIntentSenderForResult(sender, REQ_SCAN, null, 0, 0, 0)
                } catch (e: Exception) {
                    fail("unavailable", e.message)
                }
            }
            .addOnFailureListener { e -> fail("unavailable", e.message) }
    }

    private fun fail(code: String, msg: String?) {
        val p = pending ?: return
        pending = null
        p.error(code, msg ?: code, null)
    }

    /** MainActivity.onActivityResult'tan çağrılır; bizim istek değilse false. */
    fun handleResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_SCAN) return false
        val p = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK) {
            p.success(null) // vazgeçildi
            return true
        }
        val res = GmsDocumentScanningResult.fromActivityResultIntent(data)
        if (res == null) {
            p.success(null)
            return true
        }
        Thread {
            try {
                val dir = File(activity.cacheDir, "docscan").apply { mkdirs() }
                val stamp = System.currentTimeMillis()
                val jpgs = ArrayList<String>()
                res.pages?.forEachIndexed { i, page ->
                    val out = File(dir, "p${stamp}_$i.jpg")
                    activity.contentResolver.openInputStream(page.imageUri)?.use { ins ->
                        FileOutputStream(out).use { ins.copyTo(it) }
                    }
                    jpgs.add(out.absolutePath)
                }
                var pdf: String? = null
                res.pdf?.uri?.let { uri ->
                    val out = File(dir, "p$stamp.pdf")
                    activity.contentResolver.openInputStream(uri)?.use { ins ->
                        FileOutputStream(out).use { ins.copyTo(it) }
                    }
                    pdf = out.absolutePath
                }
                activity.runOnUiThread {
                    p.success(mapOf("pages" to jpgs, "pdf" to pdf))
                }
            } catch (e: Exception) {
                activity.runOnUiThread { p.error("io", e.message ?: "io", null) }
            }
        }.start()
        return true
    }
}
