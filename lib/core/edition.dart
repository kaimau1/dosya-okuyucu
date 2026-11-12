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
library;

/// Derlenen sürüm. Sıra anlamlı: her sürüm bir öncekinin üst kümesi
/// (Lite ⊂ Pro ⊂ Kişisel) — [has] bunu sıra karşılaştırmasıyla sağlar.
enum Edition {
  lite,
  pro,
  kisisel;

  static const _raw = String.fromEnvironment('DOSYA_SURUM');

  /// Bu derlemenin sürümü (derleme anı sabiti).
  static const Edition current = _raw == 'lite'
      ? Edition.lite
      : _raw == 'pro'
          ? Edition.pro
          : _raw == 'kisisel'
              ? Edition.kisisel
              : (bool.fromEnvironment('DOSYA_OKUYUCU')
                  ? Edition.lite
                  : Edition.kisisel);

  /// Metinden sürüm (CI betikleri, testler); tanınmayan → null.
  static Edition? parse(String value) {
    for (final e in values) {
      if (e.name == value.trim().toLowerCase()) return e;
    }
    return null;
  }

  /// Bu sürümde [f] var mı?
  bool has(Feature f) => index >= f.minEdition.index;

  /// Play'e giden sürüm mü (mağaza dışı güncelleme, APK kurma vb. yasak).
  bool get isPlay => this != Edition.kisisel;
}

/// Sürüme göre açılıp kapanan özellikler (SÜRÜM PLANI §1).
///
/// Lite'ın çekirdeği (açma, okuma, arama, paylaşma, yazdırma, form, elle
/// imza) burada YOK: her sürümde olan şey kapıdan geçmez.
enum Feature {
  // ── Pro (Lite'ta PRO rozetiyle görünür, dokununca tanıtım levhası) ───────
  /// Word/Excel/PowerPoint düzenleme, yeni boş belge.
  officeEdit,
  /// PDF ileri: metin düzenleme, sayfa işleri, birleştir/böl, sıkıştır,
  /// parola, karartma, karşılaştır, OCR, dijital imza, çeviri.
  pdfAdvanced,
  /// Kamera ile belge tarama.
  scan,
  /// Biçim dönüştürme (Word/Excel/slayt/görsel ↔ PDF, Markdown).
  convert,
  /// Dosya yöneticisi: gezgin, süzgeç, arama, çöp, taşı/kopyala, USB/SD, arşiv.
  fileManager,
  /// Yer açma: depolama analizi, kopyalar, akıllı temizlik, sohbet temizliği.
  cleanup,
  /// Şifreli kasa, klasör kilidi, uygulama kilidi.
  vault,
  /// Yakındakiler, QR ile paylaşım, tarayıcıdan paylaşım.
  transfer,
  /// SMB / FTP / SFTP / WebDAV bağlantıları.
  remote,
  /// Sesli kitap üretme + kitaplığı, cihaz içi doğal sesler.
  audiobook,
  /// Yapay zekâ (kullanıcının kendi anahtarı) + cihaz içi çeviri.
  ai,
  /// Video/müzik oynatıcı, galeri, görsel düzenleme/boyutlandırma.
  media,
  /// Önemli Dosyalar, ana ekran widget'ları, ayar yedeği.
  extras,

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
  labs;

  /// Bu özelliğin girdiği en düşük sürüm.
  Edition get minEdition => _minEdition[this]!;

  /// Lite'ta rozetle görünüp Pro'ya yönlendiren özellik mi?
  bool get isPro => minEdition == Edition.pro;

  /// Play sürümlerinde (Lite/Pro) hiç bulunmayan özellik mi?
  bool get isPersonalOnly => minEdition == Edition.kisisel;
}

/// **Tek tablo.** Terfi = buradaki değeri düşürmek.
const Map<Feature, Edition> _minEdition = {
  Feature.officeEdit: Edition.pro,
  Feature.pdfAdvanced: Edition.pro,
  Feature.scan: Edition.pro,
  Feature.convert: Edition.pro,
  Feature.fileManager: Edition.pro,
  Feature.cleanup: Edition.pro,
  Feature.vault: Edition.pro,
  Feature.transfer: Edition.pro,
  Feature.remote: Edition.pro,
  Feature.audiobook: Edition.pro,
  Feature.ai: Edition.pro,
  Feature.media: Edition.pro,
  Feature.extras: Edition.pro,
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
};

/// Pro sürümün Play bağlantıları ve fiyat metni (SÜRÜM PLANI §3).
abstract final class ProListing {
  /// Pro paket kimliği (S5).
  static const packageId = 'com.dosyaokuyucu.dosya_okuyucu.pro';

  /// Fiyat metni — kullanıcı kararı (👤). Boşken levhada fiyat satırı
  /// gizlenir: yanlış fiyat göstermektense hiç gösterme.
  static const priceLabel = String.fromEnvironment('DOSYA_PRO_FIYAT');

  static Uri get marketUri => Uri.parse('market://details?id=$packageId');
  static Uri get webUri =>
      Uri.parse('https://play.google.com/store/apps/details?id=$packageId');
}
