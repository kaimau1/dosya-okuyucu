package com.dosyaokuyucu.dosya_okuyucu

import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.graphics.Point
import android.os.Build
import android.os.CancellationSignal
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.os.storage.StorageManager
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.provider.DocumentsProvider
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException
import java.util.LinkedList

/**
 * **Belge sağlayıcı (SAF)** — "Şuradan aç" listesinde görünmemizi sağlar.
 *
 * KÖK NEDEN (2026-08-10, kullanıcı ekran görüntüsüyle): *"pull burada ki
 * listede bizim adımız yok."* Android'in belge seçicisindeki soldan açılan
 * çekmece ("Şuradan aç: Son / Dokümanlar / İndirilenler / Dosya Yöneticisi /
 * Drive…") **yalnızca `DocumentsProvider` bildiren uygulamaları** listeler.
 * Bizim manifestte VIEW/SEND intent-filter'ları vardı — onlar "Birlikte aç" ve
 * "Paylaş" menülerine sokar, seçici çekmecesine DEĞİL. Bu sınıf o eksiği
 * kapatır: artık başka bir uygulama dosya seçtirirken (Gmail eki, WhatsApp
 * gönderimi, tarayıcı yüklemesi) kullanıcı "Dosya Okuyucu"yu kaynak olarak
 * seçebilir.
 *
 * ## Tasarım kararları
 * - **Belge kimliği = mutlak yol.** AOSP'nin `ExternalStorageProvider`ı da
 *   böyle yapar. Ayrı bir kimlik tablosu tutmak, uygulama silinip yeniden
 *   kurulunca ya da SD kart çıkarılıp takılınca kalıcı izinlerin (persisted
 *   URI permission) bozulmasına yol açardı.
 * - **Kökler birim başına.** Dahili depolama her zaman; SD kart / USB bellek
 *   Android 11+'ta `StorageVolume.getDirectory()` ile eklenir. Daha eski
 *   sürümlerde yansımaya (reflection) başvurmak yerine yalnız dahili depolama
 *   gösterilir — yanlış yol vermektense göstermemek doğru.
 * - **Yazma açık** (`FLAG_SUPPORTS_CREATE`/`DELETE`/`RENAME`/`WRITE`): seçici
 *   yalnız "aç" için değil, "buraya kaydet" için de kullanılıyor. Yazma
 *   kapalıysa uygulamamız kaydetme akışlarında hiç görünmez.
 * - **İzin yoksa kök yine listelenir, içi boş görünür.** Uygulama depolama
 *   iznini kendi ekranında istiyor; seçicide görünmemek kullanıcıya "bu
 *   uygulama yok" izlenimi verirdi ki asıl şikâyet buydu.
 *
 * `flutter create` `android/` klasörünü her CI derlemesinde yeniden ürettiği
 * için bu dosya `ci/` altında bakımlıdır ve iş akışınca kopyalanır
 * (bkz. MainActivity.kt'deki aynı not).
 */
class DosyaProvider : DocumentsProvider() {

    override fun onCreate(): Boolean = true

    // ── kökler ──────────────────────────────────────────────────────────────

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val cursor = MatrixCursor(projection ?: DEFAULT_ROOT_PROJECTION)
        val label = try {
            context?.applicationInfo?.loadLabel(context!!.packageManager)?.toString()
        } catch (e: Exception) {
            null
        } ?: "Dosya Okuyucu"

        for ((index, root) in roots().withIndex()) {
            val row = cursor.newRow()
            row.add(Root.COLUMN_ROOT_ID, root.absolutePath)
            row.add(Root.COLUMN_DOCUMENT_ID, root.absolutePath)
            // İlk kök uygulamanın adını taşır (çekmecede aranan satır); ek
            // birimler kendi klasör adlarıyla ayrışır (SD kart, USB).
            row.add(
                Root.COLUMN_TITLE,
                if (index == 0) label else "$label · ${root.name}"
            )
            row.add(Root.COLUMN_SUMMARY, root.absolutePath)
            row.add(
                Root.COLUMN_FLAGS,
                Root.FLAG_SUPPORTS_CREATE or
                    Root.FLAG_SUPPORTS_IS_CHILD or
                    Root.FLAG_SUPPORTS_SEARCH or
                    Root.FLAG_LOCAL_ONLY
            )
            row.add(Root.COLUMN_ICON, R.mipmap.ic_launcher)
            row.add(Root.COLUMN_MIME_TYPES, "*/*")
            row.add(Root.COLUMN_AVAILABLE_BYTES, availableBytes(root))
        }
        return cursor
    }

    /** Gösterilecek depolama kökleri: dahili + (Android 11+) takılabilir birimler. */
    private fun roots(): List<File> {
        val out = ArrayList<File>()
        val primary = Environment.getExternalStorageDirectory()
        if (primary != null && primary.exists()) out.add(primary)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val manager = context?.getSystemService(StorageManager::class.java)
                for (volume in manager?.storageVolumes.orEmpty()) {
                    if (volume.isPrimary) continue
                    val dir = volume.directory ?: continue
                    if (dir.exists()) out.add(dir)
                }
            } catch (e: Exception) {
                // Birim listesi okunamadı: dahili depolama yine listede.
            }
        }
        return out
    }

    private fun availableBytes(root: File): Long = try {
        root.usableSpace
    } catch (e: Exception) {
        0L
    }

    // ── belgeler ────────────────────────────────────────────────────────────

    override fun queryDocument(
        documentId: String,
        projection: Array<out String>?
    ): Cursor {
        val cursor = MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
        addFileRow(cursor, File(documentId))
        return cursor
    }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val cursor = MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
        val parent = File(parentDocumentId)
        // Okunamayan klasör (izin verilmemiş, çıkarılmış SD kart) boş görünür;
        // istisna fırlatmak seçicide "bir sorun oluştu" penceresi açardı.
        val children = try {
            parent.listFiles()
        } catch (e: Exception) {
            null
        } ?: return cursor
        for (child in children) {
            addFileRow(cursor, child)
        }
        return cursor
    }

    /**
     * Arama: kökün altında **ada göre** özyinelemeli tarama.
     *
     * Genişlik öncelikli ve sınırlı ([SEARCH_LIMIT]): seçicideki arama kutusu
     * ana izlekte bekliyor, 100 bin dosyalı bir telefonda derin bir tarama
     * pencereyi dondururdu.
     */
    override fun querySearchDocuments(
        rootId: String,
        query: String,
        projection: Array<out String>?
    ): Cursor {
        val cursor = MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
        val needle = query.lowercase()
        val queue = LinkedList<File>()
        queue.add(File(rootId))
        var found = 0
        while (queue.isNotEmpty() && found < SEARCH_LIMIT) {
            val dir = queue.removeFirst()
            val children = try {
                dir.listFiles()
            } catch (e: Exception) {
                null
            } ?: continue
            for (child in children) {
                if (child.isDirectory) {
                    if (child.name.startsWith(".")) continue
                    queue.add(child)
                }
                if (child.name.lowercase().contains(needle)) {
                    addFileRow(cursor, child)
                    if (++found >= SEARCH_LIMIT) break
                }
            }
        }
        return cursor
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        val file = File(documentId)
        if (!file.exists()) throw FileNotFoundException(documentId)
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.parseMode(mode))
    }

    /**
     * Küçük resim: görsel/video dosyasının kendisi döner.
     *
     * Ayrıca bir küçük resim üretmiyoruz — seçici dönen akışı zaten küçültüyor
     * ve burada bitmap ölçeklemek her satırda bellek ve CPU demek olurdu.
     */
    override fun openDocumentThumbnail(
        documentId: String,
        sizeHint: Point?,
        signal: CancellationSignal?
    ): AssetFileDescriptor {
        val file = File(documentId)
        if (!file.exists()) throw FileNotFoundException(documentId)
        val descriptor =
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        return AssetFileDescriptor(descriptor, 0, AssetFileDescriptor.UNKNOWN_LENGTH)
    }

    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean {
        // Yol karşılaştırması ayıraçla yapılır: "/a/bc" yolu "/a/b" klasörünün
        // altında DEĞİLDİR — düz `startsWith` bunu yanlış bilirdi.
        val parent = File(parentDocumentId).absolutePath.trimEnd('/')
        val child = File(documentId).absolutePath
        return child.startsWith("$parent/")
    }

    // ── yazma ───────────────────────────────────────────────────────────────

    override fun createDocument(
        parentDocumentId: String,
        mimeType: String,
        displayName: String
    ): String {
        val parent = File(parentDocumentId)
        val target = uniqueFile(parent, displayName)
        try {
            val created = if (Document.MIME_TYPE_DIR == mimeType) {
                target.mkdir()
            } else {
                target.createNewFile()
            }
            if (!created) throw FileNotFoundException("oluşturulamadı: $displayName")
        } catch (e: Exception) {
            throw FileNotFoundException("oluşturulamadı: $displayName")
        }
        return target.absolutePath
    }

    override fun deleteDocument(documentId: String) {
        val file = File(documentId)
        val deleted = try {
            if (file.isDirectory) file.deleteRecursively() else file.delete()
        } catch (e: Exception) {
            false
        }
        if (!deleted) throw FileNotFoundException("silinemedi: $documentId")
    }

    override fun renameDocument(documentId: String, displayName: String): String {
        val file = File(documentId)
        val target = uniqueFile(file.parentFile ?: return documentId, displayName)
        val renamed = try {
            file.renameTo(target)
        } catch (e: Exception) {
            false
        }
        if (!renamed) throw FileNotFoundException("adlandırılamadı: $documentId")
        return target.absolutePath
    }

    /** Aynı adlı dosya varsa "ad (2).uzantı" üretir — üstüne yazmak veri kaybıdır. */
    private fun uniqueFile(parent: File, displayName: String): File {
        var candidate = File(parent, displayName)
        if (!candidate.exists()) return candidate
        val dot = displayName.lastIndexOf('.')
        val base = if (dot > 0) displayName.substring(0, dot) else displayName
        val ext = if (dot > 0) displayName.substring(dot) else ""
        var index = 2
        while (candidate.exists() && index < 1000) {
            candidate = File(parent, "$base ($index)$ext")
            index++
        }
        return candidate
    }

    // ── satır kurma ─────────────────────────────────────────────────────────

    private fun addFileRow(cursor: MatrixCursor, file: File) {
        val isDir = file.isDirectory
        var flags = 0
        if (file.canWrite()) {
            flags = flags or Document.FLAG_SUPPORTS_DELETE or
                Document.FLAG_SUPPORTS_RENAME
            flags = if (isDir) {
                flags or Document.FLAG_DIR_SUPPORTS_CREATE
            } else {
                flags or Document.FLAG_SUPPORTS_WRITE
            }
        }
        val mime = mimeOf(file)
        if (mime.startsWith("image/") || mime.startsWith("video/")) {
            flags = flags or Document.FLAG_SUPPORTS_THUMBNAIL
        }

        val row = cursor.newRow()
        row.add(Document.COLUMN_DOCUMENT_ID, file.absolutePath)
        row.add(Document.COLUMN_DISPLAY_NAME, file.name)
        row.add(Document.COLUMN_SIZE, if (isDir) 0L else file.length())
        row.add(Document.COLUMN_MIME_TYPE, mime)
        row.add(Document.COLUMN_LAST_MODIFIED, file.lastModified())
        row.add(Document.COLUMN_FLAGS, flags)
    }

    private fun mimeOf(file: File): String {
        if (file.isDirectory) return Document.MIME_TYPE_DIR
        val ext = file.extension.lowercase()
        if (ext.isEmpty()) return "application/octet-stream"
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: "application/octet-stream"
    }

    private companion object {
        const val SEARCH_LIMIT = 200

        val DEFAULT_ROOT_PROJECTION = arrayOf(
            Root.COLUMN_ROOT_ID,
            Root.COLUMN_DOCUMENT_ID,
            Root.COLUMN_TITLE,
            Root.COLUMN_SUMMARY,
            Root.COLUMN_FLAGS,
            Root.COLUMN_ICON,
            Root.COLUMN_MIME_TYPES,
            Root.COLUMN_AVAILABLE_BYTES,
        )

        val DEFAULT_DOCUMENT_PROJECTION = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_SIZE,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_LAST_MODIFIED,
            Document.COLUMN_FLAGS,
        )
    }
}
