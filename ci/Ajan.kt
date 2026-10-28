package com.dosyaokuyucu.dosya_okuyucu

import android.app.PendingIntent
import android.content.Context
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import androidx.appfunctions.AppFunctionDeclaration
import androidx.appfunctions.AppFunctionElementNotFoundException
import androidx.appfunctions.AppFunctionInvalidArgumentException
import androidx.appfunctions.AppFunctionSerializable
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionServiceEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * **Gemini işlevleri** (Android 16+ AppFunctions, 2026-10-28): bir ajan son
 * açılanları görür, dosya adında arar, dosyayı ya da bir ekranı açtırır.
 * Arayüz isteyen her işlev `intentToOpen` (PendingIntent) döndürür, ajan onu
 * başlatır — arka plandaki servisten Activity açmak Android 10+'da engelli.
 * Bağlantılar widget'larınkiyle AYNI (`Extras.linkIntent`, `app:` / `file:`).
 *
 * **GİZLİLİK — `lib/services/fm/ai_scope.dart` ile aynı kural:** kilitli
 * klasörler (`fm_locked_folders`), AI kapsamından dışlanan klasörler
 * (`ai_scope.excluded`, varsayılanda `DCIM/Camera`) ve gizli/sistem yolları
 * ajana HİÇ dönmez. Gemini de bir AI; kullanıcının "kameramdaki fotoğraflara
 * erişmesin" kararı burada da geçerli. Ayar okunamazsa sonuç BOŞ döner —
 * kaydı okuyamamak yüzünden "her şey açık"a düşmek kabul edilemez.
 *
 * KDoc'lar ajanın okuduğu açıklamadır; işlevin ne zaman seçileceğini o belirler.
 */

/** A file on the phone. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class AjanDosya(
    /** File name with extension. */
    val name: String,
    /** Absolute path; pass it to openFile. */
    val path: String,
)

/** Launch intentToOpen to show the result in Dosya Okuyucu. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class AjanAcma(
    /** Launch this to open Dosya Okuyucu. */
    val intentToOpen: PendingIntent,
    /** Short description of what will open, in Turkish. */
    val message: String,
)

@RequiresApi(36)
@AppFunctionServiceEntryPoint(serviceName = "AjanServisi", appFunctionXmlFileName = "dosya_ajan")
abstract class AjanTemel : AppFunctionService() {

    /**
     * Lists the files the user most recently opened in Dosya Okuyucu.
     *
     * @return Up to 10 files, most recent first.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    fun recentFiles(): List<AjanDosya> {
        val recent = Extras.widgetData(this).optJSONArray("recent") ?: return emptyList()
        val kapsam = AjanKapsam.oku(this) ?: return emptyList()
        return (0 until recent.length()).mapNotNull { recent.optJSONObject(it) }
            .map { AjanDosya(it.optString("name"), it.optString("path")) }
            .filter { it.path.isNotEmpty() && kapsam.izinli(it.path) && File(it.path).exists() }
    }

    /**
     * Searches files on the phone by name (documents, PDFs, spreadsheets, images, audio…).
     *
     * @param query Part of the file name, e.g. "fatura" or "kira sözleşmesi".
     * @return Up to 20 matching files, most recently modified first.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun searchFiles(query: String): List<AjanDosya> = withContext(Dispatchers.IO) {
        val kelimeler = query.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        if (kelimeler.isEmpty()) throw AppFunctionInvalidArgumentException("query boş olamaz")
        val kapsam = AjanKapsam.oku(this@AjanTemel) ?: return@withContext emptyList()
        val secim = kelimeler.joinToString(" AND ") { "${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?" }
        val args = kelimeler.map { "%" + it.replace("%", "").replace("_", "") + "%" }.toTypedArray()
        val sonuc = mutableListOf<AjanDosya>()
        contentResolver.query(
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
            arrayOf(MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.DATA),
            secim, args, "${MediaStore.MediaColumns.DATE_MODIFIED} DESC",
        )?.use { c ->
            while (c.moveToNext() && sonuc.size < 20) {
                val ad = c.getString(0) ?: continue
                val yol = c.getString(1) ?: continue
                if (kapsam.izinli(yol) && File(yol).isFile) sonuc += AjanDosya(ad, yol)
            }
        }
        sonuc
    }

    /**
     * Opens a file in Dosya Okuyucu (viewer/editor for PDF, Word, Excel, slides, images, audio).
     *
     * @param path Absolute path from recentFiles or searchFiles.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    fun openFile(path: String): AjanAcma {
        val kapsam = AjanKapsam.oku(this)
        val f = File(path)
        if (kapsam == null || !kapsam.izinli(f.path) || !f.isFile) {
            throw AppFunctionElementNotFoundException("Dosya bulunamadı: $path")
        }
        return ac("file:" + f.path, f.name)
    }

    /**
     * Opens a screen of Dosya Okuyucu.
     *
     * @param screen One of: "scan" (scan a document with the camera), "search", "downloads",
     *   "recent" (recently opened), "clean" (free up storage), "photos", "videos", "bills".
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    fun openScreen(screen: String): AjanAcma {
        val s = screen.trim().lowercase()
        if (s !in EKRANLAR) throw AppFunctionInvalidArgumentException("Bilinmeyen ekran: $screen")
        return ac("app:$s", s)
    }

    private fun ac(link: String, message: String): AjanAcma {
        val pi = Extras.linkIntent(this, link)
            ?: throw AppFunctionElementNotFoundException("Uygulama başlatılamıyor")
        return AjanAcma(pi, message)
    }

    private companion object {
        val EKRANLAR = setOf("scan", "search", "downloads", "recent", "clean", "photos", "videos", "bills")
    }
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
