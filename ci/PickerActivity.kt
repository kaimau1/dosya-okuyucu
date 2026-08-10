package com.dosyaokuyucu.dosya_okuyucu

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * **Seçici kipi aktivitesi** — "Şuradan aç" çekmecesindeki *ok işareti*.
 *
 * KÖK NEDEN (2026-08-10, kullanıcı ekran görüntüsüyle): *"biz çıkıyoruz ama
 * bizim arayüzümüze yönlendiren işaret çıkmıyor."* O çekmecede iki tür satır
 * var: `DocumentsProvider` kökleri (seçicinin kendi arayüzünde gezilir — bizim
 * `DosyaProvider` ile kazandığımız satır) ve `ACTION_GET_CONTENT` karşılayan
 * **uygulamalar** (yanlarında ok vardır; dokununca o uygulamanın kendi ekranı
 * açılır — Drive ve MIUI Dosya Yöneticisi böyle). Ok için gereken bu aktivite.
 *
 * ## Neden AYRI bir aktivite, neden MainActivity'ye filtre eklenmedi
 * `MainActivity` `launchMode="singleTask"`. Android'de singleTask (ve
 * singleInstance) bir aktivite **sonuç döndüremez**: `startActivityForResult`
 * çağıran uygulamaya anında `RESULT_CANCELED` verilir. Filtreyi oraya koymak,
 * listede görünen ama hiçbir zaman dosya veremeyen bir satır üretirdi —
 * kullanıcı için "tıkladım, hiçbir şey olmadı".
 *
 * ## Dosya nasıl teslim ediliyor
 * Seçilen yol kendi belge sağlayıcımızın adresine çevrilir
 * (`content://…documents/document/<yol>`) ve sonuç niyetine
 * `FLAG_GRANT_READ_URI_PERMISSION` eklenir. Sağlayıcı
 * `grantUriPermissions="true"` bildirdiği için bu bayrak, sağlayıcının
 * `MANAGE_DOCUMENTS` korumasına rağmen **yalnız o adres için** çağırana geçici
 * okuma izni verir. Böylece dosyayı kopyalamadan, kendi depolamamızı çağırana
 * açmadan teslim ediyoruz.
 *
 * `flutter create` `android/` klasörünü her CI derlemesinde yeniden ürettiği
 * için bu dosya `ci/` altında bakımlıdır ve iş akışınca kopyalanır.
 */
class PickerActivity : FlutterActivity() {

    /**
     * Flutter tarafı bu yola bakıp ana ekran yerine seçici ekranını açar
     * (bkz. `lib/main.dart` → `pickerRoute`). İki taraftaki değer AYNI olmalı.
     */
    override fun getInitialRoute(): String = "/picker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Çağıran ne istiyor: tür süzgeci + çoklu seçim.
                    "request" -> result.success(
                        mapOf(
                            "mimeType" to (intent?.type ?: "*/*"),
                            "multiple" to (intent?.getBooleanExtra(
                                Intent.EXTRA_ALLOW_MULTIPLE, false
                            ) ?: false),
                        )
                    )

                    "pick" -> result.success(
                        deliver(call.argument<List<String>>("paths"))
                    )

                    "cancel" -> {
                        // Boş sonuçla kapanmak yerine AÇIKÇA iptal: çağıran
                        // uygulama "kullanıcı vazgeçti" ile "dosya alamadım"
                        // durumlarını ayırt edebilmeli.
                        setResult(RESULT_CANCELED)
                        finish()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /** Seçilen yolları sonuç olarak döndürür. Hiçbiri okunamazsa `false`. */
    private fun deliver(paths: List<String>?): Boolean {
        if (paths.isNullOrEmpty()) return false
        val uris = ArrayList<Uri>()
        for (path in paths) {
            // Var olmayan/okunamayan dosyayı teslim etmek, çağıranda sessiz bir
            // hataya dönüşür — baştan eleniyor.
            if (!File(path).isFile) continue
            uris.add(DocumentsContract.buildDocumentUri(AUTHORITY, path))
        }
        if (uris.isEmpty()) return false

        val data = Intent()
        if (uris.size == 1) {
            data.data = uris[0]
        } else {
            // Çoklu seçimde adres listesi ClipData ile taşınır (SAF geleneği);
            // `data` alanına ilk dosya da konur ki yalnız onu okuyan eski
            // uygulamalar boş dönmesin.
            data.data = uris[0]
            val clip = ClipData.newUri(contentResolver, "files", uris[0])
            for (i in 1 until uris.size) {
                clip.addItem(ClipData.Item(uris[i]))
            }
            data.clipData = clip
        }
        data.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
        setResult(RESULT_OK, data)
        finish()
        return true
    }

    private companion object {
        const val CHANNEL = "dosya_okuyucu/picker"
        const val AUTHORITY = "com.dosyaokuyucu.dosya_okuyucu.documents"
    }
}
