package com.dosyaokuyucu.dosya_okuyucu

import android.app.Service
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import android.util.Log
import java.io.File

/**
 * **Asistan köprüsü — YALNIZ KİŞİSEL DERLEME** (`DOSYA_KISISEL=1 bash ci/prepare_android.sh`; 2026-10-31).
 *
 * Kullanıcının kişisel sesli asistanı (`com.ses.asistan`, ayrı uygulama) "X dosyasını aç", "son dosyayı aç",
 * "sesli oku", "okumayı durdur", "özetle" komutlarını buraya `KOMUT` iletisiyle verir; cevap `SONUÇ` ile döner.
 * Okuma ve özet uygulamanın kendi kodudur: köprü yalnız `oku:` / `ozet:` / `durdur:` bağlantısını verir, asistan
 * uygulamayı onunla açar, Dart'taki kanca açık görüntüleyicide `TtsService`'i ya da AI özetini başlatır.
 * Sözleşme asistan deposunun `PROTOKOL.md`'sinde ("Dosya Okuyucu komutları"); buraya o depodan kod kopyalanmaz,
 * sabitler belgeden yazıldı.
 *
 * * **Genel (dağıtılan) APK'da bu dosya, servis ve izin YOKTUR** — `prepare_android.sh` bayrak yokken eklemez ve
 *   üretilen manifestte köprü olmadığını denetler.
 * * Uygulamanın kendi ses özelliklerine (`tts_service`, sesli kitap) dokunulmaz; yalnız başlatılır.
 * * Güvenlik: servis `…izin.ASISTAN` (`signature|knownSigner`, knownCerts = asistanın sertifikası) ile korunur;
 *   ayrıca iletiyi gönderenin paketi denetlenir.
 * * Gizlilik: arama ve son açılanlar Gemini işlevleriyle AYNI kapsam kuralından geçer (`DosyaArama`, kilitli ve AI
 *   dışı klasörler hiç dönmez).
 *
 * Flutter'a bağlı değil (`tool/check_kotlin.sh` gerçek Android jar'ına karşı derler).
 */
class AsistanKopru : Service() {
    private lateinit var isci: HandlerThread
    private lateinit var gelen: Messenger

    override fun onCreate() {
        super.onCreate()
        isci = HandlerThread("asistan-kopru").apply { start() }
        // disk ve MediaStore işi kendi iş parçacığında (ana iş parçacığında değil)
        gelen = Messenger(Handler(isci.looper) { m -> isle(m); true })
    }

    override fun onBind(intent: Intent?): IBinder = gelen.binder

    override fun onDestroy() {
        isci.quitSafely()
        super.onDestroy()
    }

    private fun isle(m: Message) {
        if (m.what != KOMUT) return // METİN devri yok (`ses_yetenekler.xml` devir="hayir")
        val paketler = packageManager.getPackagesForUid(m.sendingUid).orEmpty()
        if (ASISTAN !in paketler) return
        val d = m.data ?: Bundle.EMPTY
        val kimlik = d.getInt("kimlik")
        val (metin, tamam, link) = runCatching { cevap(d.getString("ad").orEmpty(), d.getString("sorgu").orEmpty()) }
            .getOrElse { Log.w(TAG, "komut işlenemedi", it); Cevap("Dosya Okuyucu'da bir hata oldu.", false) }
        val c = Message.obtain(null, SONUC).apply {
            data = Bundle().apply {
                putInt("kimlik", kimlik)
                putString("metin", metin)
                putBoolean("tamam", tamam)
                link?.let { l -> Extras.linkIntent(this@AsistanKopru, l)?.let { putParcelable("pi", it) } }
            }
        }
        runCatching { m.replyTo?.send(c) }.onFailure { Log.w(TAG, "cevap gönderilemedi", it) }
    }

    /** [link] verilirse asistan uygulamayı o bağlantıyla açar (`app_links.dart` biçimi). */
    internal data class Cevap(val metin: String, val tamam: Boolean, val link: String? = null)

    internal fun cevap(ad: String, sorgu: String): Cevap {
        if (ad == "durdur") return Cevap("Okuma durduruluyor.", true, BAG_DURDUR)
        val onek = when (ad) {
            "ac" -> "file:"
            // Sesli okuma ve özet uygulamanın kendi kodunda (`TtsService`, AI özeti); bağlantıyı Dart'taki kanca
            // karşılar (`lib/services/asistan_komutlari.dart`, asistan PLAN K7).
            "oku" -> BAG_OKU
            "ozetle" -> BAG_OZET
            else -> return Cevap("Dosya Okuyucu bu komutu bilmiyor.", false)
        }
        val bulunan = if (sorgu.isBlank()) DosyaArama.son(this).take(1) else DosyaArama.ara(this, sorgu, 5)
        val f = bulunan.firstOrNull()
        return when {
            f == null && sorgu.isBlank() -> Cevap("Son açılan dosya yok.", false)
            f == null -> Cevap("Adında “$sorgu” geçen dosya bulunamadı.", false)
            !DosyaArama.izinli(this, File(f.yol)) -> Cevap("Dosya bulunamadı.", false)
            else -> Cevap(cumle(ad, f.ad, bulunan.size), true, onek + f.yol)
        }
    }

    companion object {
        private const val TAG = "AsistanKopru"
        private const val ASISTAN = "com.ses.asistan"
        // PROTOKOL.md (asistan deposu): Message.what
        private const val KOMUT = 107
        private const val SONUC = 9

        // Dart kancasının bağlantıları (`app_links.dart`); "file:" uygulamanın eski bağlantısı
        internal const val BAG_OKU = "oku:"
        internal const val BAG_OZET = "ozet:"
        internal const val BAG_DURDUR = "durdur:"

        /** "fatura.pdf açılıyor" / "3 dosya bulundu, en yenisi açılıyor: fatura.pdf". */
        internal fun acilisCumlesi(ad: String, adet: Int): String =
            if (adet <= 1) "$ad açılıyor." else "$adet dosya bulundu, en yenisi açılıyor: $ad."

        /** Komuta göre cevap: aç → [acilisCumlesi]; oku → "fatura.pdf okunuyor."; özet → "fatura.pdf özetleniyor." */
        internal fun cumle(komut: String, ad: String, adet: Int): String = when (komut) {
            "oku" -> "$ad okunuyor."
            "ozetle" -> "$ad özetleniyor; özet Dosya Okuyucu'da açılacak."
            else -> acilisCumlesi(ad, adet)
        }
    }
}
