package com.dosyaokuyucu.dosya_okuyucu

import android.app.PendingIntent
import androidx.annotation.RequiresApi
import androidx.appfunctions.AppFunctionDeclaration
import androidx.appfunctions.AppFunctionElementNotFoundException
import androidx.appfunctions.AppFunctionInvalidArgumentException
import androidx.appfunctions.AppFunctionSerializable
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionServiceEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * **Gemini işlevleri** (Android 16+ AppFunctions, 2026-10-28): bir ajan son
 * açılanları görür, dosya adında arar, dosyayı ya da bir ekranı açtırır.
 * Arayüz isteyen her işlev `intentToOpen` (PendingIntent) döndürür, ajan onu
 * başlatır — arka plandaki servisten Activity açmak Android 10+'da engelli.
 * Bağlantılar widget'larınkiyle AYNI (`Extras.linkIntent`, `app:` / `file:`).
 *
 * Arama ve kapsam `DosyaArama.kt`'de (asistan köprüsü de aynısını kullanır).
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
    fun recentFiles(): List<AjanDosya> = DosyaArama.son(this).map { AjanDosya(it.ad, it.yol) }

    /**
     * Searches files on the phone by name (documents, PDFs, spreadsheets, images, audio…).
     *
     * @param query Part of the file name, e.g. "fatura" or "kira sözleşmesi".
     * @return Up to 20 matching files, most recently modified first.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun searchFiles(query: String): List<AjanDosya> = withContext(Dispatchers.IO) {
        if (query.isBlank()) throw AppFunctionInvalidArgumentException("query boş olamaz")
        DosyaArama.ara(this@AjanTemel, query).map { AjanDosya(it.ad, it.yol) }
    }

    /**
     * Opens a file in Dosya Okuyucu (viewer/editor for PDF, Word, Excel, slides, images, audio).
     *
     * @param path Absolute path from recentFiles or searchFiles.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    fun openFile(path: String): AjanAcma {
        val f = File(path)
        if (!DosyaArama.izinli(this, f)) throw AppFunctionElementNotFoundException("Dosya bulunamadı: $path")
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
