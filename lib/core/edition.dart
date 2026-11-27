/// **Sürüm kapısı** (SÜRÜM PLANI S1, 2026-11-12): tek kod tabanı, üç sürüm.
///
/// - **Lite** — Play, ücretsiz: aç, oku, bul, paylaş; form doldur, elle imzala.
/// - **Pro** — Play, ücretli ayrı uygulama: Lite + düzenleme, araçlar, dosya
///   yöneticisi, AI …
/// - **Kişisel** — yalnız GitHub: her şey + deneysel + Play'in izin vermediği.
///
/// Sürüm derlemede seçilir: `--dart-define=DOSYA_SURUM=lite|pro|kisisel`.
/// Tanımsızsa eski bayraklar okunur (CI kırılmasın): `DOSYA_OKUYUCU=true` →
/// Lite, aksi halde Kişisel (bugünkü nightly = her şey açık).
///
/// **Kural:** hangi özelliğin hangi sürümde olduğu YALNIZ burada, [_minEdition]
/// tablosunda yazar. Arayüz `Edition.current.has(Feature.x)` ya da
/// `ProGate` ile sorar; başka dosyada sürüm adı karşılaştırılmaz.
/// Yeni/deneysel özellik önce [Edition.kisisel]'e girer, olgunlaşınca terfi.
///
/// **K15 (2026-11-27):** Lite ile Pro AYNI uygulama — Lite'ta tek seferlik
/// uygulama içi satın alım ([ProUnlock.owned], `ProPurchase`) Pro katmanını
/// açar. Ayrı Pro derlemesi CI'da kalır, mağazaya çıkmaz.
library;

import 'package:flutter/foundation.dart' show ValueNotifier;

/// Derlenen sürüm. Sıra anlamlı: her sürüm bir öncekinin üst kümesi
/// (Lite ⊂ Pro ⊂ Kişisel) — [has] bunu sıra karşılaştırmasıyla sağlar.
enum Edition {
  lite,
  pro,
  kisisel;

  static const _raw = String.fromEnvironment('DOSYA_SURUM');
  static const _play = String.fromEnvironment('DOSYA_PLAY');

  /// Bu derlemenin sürümü (derleme anı sabiti).
  static const Edition current = _raw == 'lite'
      ? Edition.lite
      : _raw == 'pro'
          ? Edition.pro
          : _raw == 'kisisel'
              ? Edition.kisisel
              : (bool.fromEnvironment('DOSYA_OKUYUCU')
                  ? Edition.lite
                  : ((_play == '1' || _play == 'true')
                      ? Edition.pro
                      : Edition.kisisel));

  /// Metinden sürüm (CI betikleri, testler); tanınmayan → null.
  static Edition? parse(String value) {
    for (final e in values) {
      if (e.name == value.trim().toLowerCase()) return e;
    }
    return null;
  }

  /// Bu sürümde [f] var mı? (Satın alınmış Lite Pro sayılır.)
  bool has(Feature f) => tier.index >= f.minEdition.index;

  /// Özellik katmanı: Lite + Pro satın alımı → [pro]; aksi halde kendisi.
  /// Yalnız-Kişisel özellikler satın alımla AÇILMAZ.
  Edition get tier => this == lite && ProUnlock.owned.value ? pro : this;

  /// Pro katmanı açık mı (Pro/Kişisel derleme ya da satın alınmış Lite)?
  bool get proActive => tier.index >= pro.index;

  /// Bu sürümün Play / Android paket kimliği (`ci/prepare_android.sh` ve
  /// `build-apk.yml` ile birebir aynı).
  String get packageId => switch (this) {
        lite => 'com.dosyaokuyucu.dosya_okuyucu.lite',
        pro => 'com.dosyaokuyucu.dosya_okuyucu.pro',
        kisisel => 'com.dosyaokuyucu.dosya_okuyucu',
      };

  /// Play'e giden sürüm mü (mağaza dışı güncelleme, APK kurma vb. yasak).
  bool get isPlay => this != Edition.kisisel;
}

/// Sürüme göre açılıp kapanan özellikler (SÜRÜM PLANI §1).
///
/// Lite'ın çekirdeği (açma, okuma, arama, paylaşma, yazdırma, form, elle
/// imza, temel düzenleme ve dosya yöneticisi) [Edition.lite] ile açıktır.
enum Feature {
  // ── Lite'ta da açık olan çekirdek + araçlar (Edition.lite) ─────────────
  /// Word/Excel/PowerPoint temel görüntüleme, düzenleme, yeni boş belge.
  officeEdit,
  /// Kamera ile belge tarama + çevrimdışı OCR.
  scan,
  /// Biçim dönüştürme (Word/Excel/slayt/görsel ↔ PDF, Markdown).
  convert,
  /// Dosya yöneticisi: gezgin, süzgeç, arama, çöp, taşı/kopyala, USB/SD, arşiv.
  fileManager,
  /// Yer açma: depolama analizi, kopyalar, yerel temizlik.
  cleanup,
  /// Şifreli kasa, klasör kilidi, uygulama kilidi.
  vault,
  /// Yakındakiler, QR ile paylaşım, tarayıcıdan paylaşım.
  transfer,
  /// SMB / SFTP / WebDAV bağlantıları.
  remote,
  /// Video/müzik oynatıcı, galeri, görsel boyutlandırma/döndürme, kırpma.
  media,
  /// Önemli Dosyalar, ana ekran widget'ları, ayar yedeği.
  extras,

  // ── Pro (6 sütun — Lite'ta PRO rozetiyle görünür, dokununca tanıtım levhası)
  /// Akıllı klasörler (yerel + BYOK / kota).
  smartFolders,
  /// PDF düzenleme ve ileri PDF araçları (form doldurma + elle imza Lite'ta açık).
  pdfAdvanced,
  /// Video boyut düşürme / yeniden kodlama.
  videoCompress,
  /// Word ve Slayt gelişmiş biçimlendirme / Pro şablon & araçlar.
  wordSlidesPro,
  /// Sesli kitap oluşturma + kitaplığı, gelişmiş motor/temizlik.
  audiobook,
  /// Yapay zekâ (BYOK Gemini anahtarı: Akıllı klasörler, Taranmış OCR, Sesli kitap).
  ai,

  // ── Yalnız Kişisel (Lite/Pro'da HİÇ çizilmez) ───────────────────────────
  /// APK kurma / dışa aktarma (`REQUEST_INSTALL_PACKAGES`).
  apkInstall,
  /// Yüklü uygulamalar + son kullanım (`QUERY_ALL_PACKAGES`, usage stats).
  installedApps,
  /// GitHub'dan kendi kendini güncelleme.
  selfUpdate,
  /// İndirme yöneticisi + tarayıcı bağlantısı yakalama.
  downloadManager,
  /// İnternette altyazı arama.
  subtitleSearch,
  /// Google Drive (tam kapsam).
  googleDrive,
  /// Telefonu FTP sunucusu yapma.
  ftpServer,
  /// Arka planda sürekli görünürlük, açılışta başlayan işler.
  backgroundServices,
  /// Sesli not / dikte, sessiz AI turu, asistan işlevleri.
  voiceAssistant,
  /// USB tanılama, SD birleştirme, laboratuvar, bitmemiş PDF Pro motoru.
  labs,
  /// Kokoro (eSpeak NG, GPL-3.0) ve çevrimiçi Microsoft "Ahmet" sesi
  /// (2026-11-25: Play temizliğinde çıkmıştı, kullanıcı geri istedi).
  extraVoices;

  /// Bu özelliğin girdiği en düşük sürüm.
  Edition get minEdition => _minEdition[this]!;

  /// Lite'ta rozetle görünüp Pro'ya yönlendiren özellik mi?
  bool get isPro => minEdition == Edition.pro;

  /// Play sürümlerinde (Lite/Pro) hiç bulunmayan özellik mi?
  bool get isPersonalOnly => minEdition == Edition.kisisel;
}

/// **Tek tablo.** Terfi = buradaki değeri düşürmek.
const Map<Feature, Edition> _minEdition = {
  Feature.officeEdit: Edition.lite,
  Feature.scan: Edition.lite,
  Feature.convert: Edition.lite,
  Feature.fileManager: Edition.lite,
  Feature.cleanup: Edition.lite,
  Feature.vault: Edition.lite,
  Feature.transfer: Edition.lite,
  Feature.remote: Edition.lite,
  Feature.media: Edition.lite,
  Feature.extras: Edition.lite,
  Feature.smartFolders: Edition.pro,
  Feature.pdfAdvanced: Edition.pro,
  Feature.videoCompress: Edition.pro,
  Feature.wordSlidesPro: Edition.pro,
  Feature.audiobook: Edition.pro,
  Feature.ai: Edition.pro,
  Feature.apkInstall: Edition.kisisel,
  Feature.installedApps: Edition.kisisel,
  Feature.selfUpdate: Edition.kisisel,
  Feature.downloadManager: Edition.kisisel,
  Feature.subtitleSearch: Edition.kisisel,
  Feature.googleDrive: Edition.kisisel,
  Feature.ftpServer: Edition.kisisel,
  Feature.backgroundServices: Edition.kisisel,
  Feature.voiceAssistant: Edition.kisisel,
  Feature.labs: Edition.kisisel,
  Feature.extraVoices: Edition.kisisel,
};

/// Lite'taki tek seferlik Pro satın alımının durumu. YALNIZ `ProPurchase`
/// (Play kaydı) yazar; arayüz dinleyip rozetleri yeniler.
abstract final class ProUnlock {
  static final ValueNotifier<bool> owned = ValueNotifier(false);
}

/// Pro sürümün Play bağlantıları ve fiyat metni (SÜRÜM PLANI §3).
abstract final class ProListing {
  /// Pro paket kimliği (S5).
  static const packageId = 'com.dosyaokuyucu.dosya_okuyucu.pro';

  /// Fiyat metni — lansman fiyatı varsayılanı (`29,99 TL`), derlemede
  /// `DOSYA_PRO_FIYAT` ile değişebilir.
  static const priceLabel =
      String.fromEnvironment('DOSYA_PRO_FIYAT', defaultValue: '29,99 TL');

  static Uri get marketUri => Uri.parse('market://details?id=$packageId');
  static Uri get webUri =>
      Uri.parse('https://play.google.com/store/apps/details?id=$packageId');
}
