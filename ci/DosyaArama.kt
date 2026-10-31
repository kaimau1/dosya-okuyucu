package com.dosyaokuyucu.dosya_okuyucu

import android.content.Context
import android.os.Environment
import android.provider.MediaStore
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * **Dosya arama + AI kapsamı** — Gemini işlevleri (`Ajan.kt`) ile asistan köprüsünün (`ci/kisisel/AsistanKopru.kt`,
 * yalnız kişisel derleme) ortak kısmı (2026-10-31, Ajan.kt'den taşındı; davranış aynı). Flutter'a bağlı değil:
 * `tool/check_kotlin.sh` gerçek Android jar'ına karşı derler.
 */
internal object DosyaArama {
    class Bulunan(val ad: String, val yol: String)

    /** Son açılanlar (en yenisi önce, en çok 10); kapsam dışı ve silinmiş olanlar atlanır. */
    fun son(ctx: Context): List<Bulunan> {
        val recent = Extras.widgetData(ctx).optJSONArray("recent") ?: return emptyList()
        val kapsam = AjanKapsam.oku(ctx) ?: return emptyList()
        return (0 until recent.length()).mapNotNull { recent.optJSONObject(it) }
            .map { Bulunan(it.optString("name"), it.optString("path")) }
            .filter { it.yol.isNotEmpty() && kapsam.izinli(it.yol) && File(it.yol).exists() }
    }

    /** Dosya adında her kelime geçen dosyalar (en son değişen önce, en çok [enCok]). Ana iş parçacığında çağrılmaz. */
    fun ara(ctx: Context, query: String, enCok: Int = 20): List<Bulunan> {
        val kelimeler = query.trim().split(BOSLUK).filter { it.isNotEmpty() }
        if (kelimeler.isEmpty()) return emptyList()
        val kapsam = AjanKapsam.oku(ctx) ?: return emptyList()
        val secim = kelimeler.joinToString(" AND ") { "${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?" }
        val args = kelimeler.map { "%" + it.replace("%", "").replace("_", "") + "%" }.toTypedArray()
        val sonuc = mutableListOf<Bulunan>()
        ctx.contentResolver.query(
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
            arrayOf(MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.DATA),
            secim, args, "${MediaStore.MediaColumns.DATE_MODIFIED} DESC",
        )?.use { c ->
            while (c.moveToNext() && sonuc.size < enCok) {
                val ad = c.getString(0) ?: continue
                val yol = c.getString(1) ?: continue
                if (kapsam.izinli(yol) && File(yol).isFile) sonuc += Bulunan(ad, yol)
            }
        }
        return sonuc
    }

    /** Dosya var ve AI kapsamında mı (ayar okunamazsa hayır). */
    fun izinli(ctx: Context, f: File): Boolean = AjanKapsam.oku(ctx)?.izinli(f.path) == true && f.isFile

    private val BOSLUK = Regex("\\s+")
}

/** Ajanın göremeyeceği yollar; Dart'ın `FlutterSharedPreferences` kaydından okunur. */
internal class AjanKapsam(private val engelli: List<String>) {
    fun izinli(yol: String): Boolean {
        val p = File(yol).absolutePath
        // gizli klasörler (uygulamanın çöpü .dosya-okuyucu-cop, .thumbnails, .trashed) ve
        // ai_scope.dart › _hardBlocked'daki öbür sabit dışlamalar
        if (p.split('/').any { it.startsWith(".") || it == "lost+found" || it == "cache" }) return false
        return engelli.none { p == it || p.startsWith("$it/") }
    }

    companion object {
        /** shared_preferences_android 2.4: dize listesi bu önekle JSON olarak yazılır. */
        private const val LISTE_ONEKI = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"

        /** null: ayar okunamadı — çağıran BOŞ sonuç döner. */
        fun oku(ctx: Context): AjanKapsam? = runCatching {
            val sp = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val kok = Environment.getExternalStorageDirectory().absolutePath
            val engelli = mutableListOf("$kok/Android/data", "$kok/Android/obb")
            sp.getString("flutter.fm_locked_folders", null)?.let { ham ->
                if (!ham.startsWith(LISTE_ONEKI)) return null
                val a = JSONArray(ham.removePrefix(LISTE_ONEKI))
                for (i in 0 until a.length()) engelli += File(a.getString(i)).absolutePath
            }
            // Kapsam hiç yazılmadıysa Dart'ın tohumladığı varsayılan: kamera klasörü kapalı
            val scope = sp.getString("flutter.ai_scope", null)
            if (scope == null) engelli += listOf("$kok/DCIM/Camera", "$kok/DCIM/100ANDRO")
            else JSONObject(scope).optJSONArray("excluded")?.let { a ->
                for (i in 0 until a.length()) engelli += File(a.getString(i)).absolutePath
            }
            AjanKapsam(engelli)
        }.getOrNull()
    }
}
