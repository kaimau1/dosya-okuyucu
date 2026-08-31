/// **Ağ paylaşımının kapsamı** — "telefonun neresi paylaşılıyor?" sorusunun
/// tek cevabı.
///
/// ## Niye eklendi (kullanıcı isteği 2026-08-31)
/// *"ağ paylaşımında hangi klasörlerin paylaşılacağını seçelim, bir de ayrı
/// olarak paylaşılan klasörü olsun, kişi göndermek istediği şeyi oraya atsın
/// ve sadece o klasör paylaşılır."*
///
/// Paylaşım o güne dek **hep ya hep yoktu**: açıldığı anda telefonun tamamı
/// (`/Telefon`) ve bütün kutular ağdaki herkese açılıyordu. "Şu iki dosyayı
/// PC'ye atayım" diyen kullanıcı, aynı hareketle bütün fotoğraflarını,
/// belgelerini ve WhatsApp klasörünü de açmış oluyordu. Seçim yapılamadığı
/// için tek çare paylaşımı hemen kapatmaktı.
///
/// ## İki kip
/// - [ShareMode.boxes] — kutular tek tek seçilir (varsayılan: hepsi açık,
///   yani eski davranış birebir korunur).
/// - [ShareMode.sharedOnly] — **yalnız "Paylaşılan" klasörü**. Kullanıcı
///   göndermek istediğini oraya kopyalar (dosyanın ⋮ menüsünde
///   *Paylaşılan'a kopyala*), telefonun geri kalanı ağda GÖRÜNMEZ.
///
/// ## Kapsam nerede uygulanıyor
/// Tek yerde: `FtpTree` (kök listesi ve yol çözümü). FTP oturumu da HTTP
/// paylaşımı da aynı ağacı kullanıyor — iki kopya olsaydı biri kısıtlanıp
/// diğeri açık kalabilirdi. Kapsam dışı bir kutu **listelenmez ve
/// çözülmez**: adresi bilen biri `/Belgeler/gizli.pdf` yazarak da giremez.
library;

/// Kapsam kipi.
enum ShareMode {
  /// Seçilen kutular paylaşılır.
  boxes,

  /// Yalnız "Paylaşılan" klasörü paylaşılır.
  sharedOnly,
}

/// Paylaşım kapsamı — **değişmez** (immutable) bir değer.
class ShareScope {
  final ShareMode mode;

  /// Seçili kutu adları. **`null` = hepsi** (ilk kurulum ve eski davranış);
  /// boş küme = hiçbiri (kullanıcı elle temizledi, ekran uyarıyor).
  ///
  /// Boş küme ile `null` arasındaki fark bilinçli: "hiç seçmedim" ile
  /// "hepsini kaldırdım" aynı şey değil. Boş kümeyi hepsi saymak,
  /// kullanıcının bilerek kapattığı paylaşımı geri açardı.
  final Set<String>? boxes;

  const ShareScope({this.mode = ShareMode.boxes, this.boxes});

  /// Varsayılan: her şey paylaşılır (2026-08-31 öncesinin davranışı).
  static const all = ShareScope();

  /// Yalnız "Paylaşılan" klasörü.
  static const sharedOnly = ShareScope(mode: ShareMode.sharedOnly);

  // ── "Paylaşılan" klasörü ──────────────────────────────────────────────────

  /// Paylaşımda görünen kutu adı. **Aksansız (ASCII)**: kök kutu adları FTP'de
  /// istemcinin kod sayfasıyla çözülüyor ve Türkçe harf taşıyan bir kutu
  /// Windows Gezgini'nde hem bozuk görünüyor hem de AÇILMIYOR (gerekçe
  /// `FtpTree`'nin başındaki notta).
  static const sharedBox = 'Paylasilan';

  /// Telefondaki GERÇEK klasörün adı — kullanıcı bunu dosya yöneticisinde
  /// görüyor, orada aksanlı doğru yazım kullanılıyor ("Önemli Dosyalar"
  /// klasöründeki karar ile aynı). Diskteki ad ile ağdaki kutu adının
  /// ayrılması sorun değil: `Indirilenler` kutusu da gerçekte `Download`.
  ///
  /// **DİKKAT:** bu bir klasör adı, arayüz metni değil — çevrilirse var olan
  /// klasör bulunamaz ve kullanıcı dosyalarını kaybetmiş sanır.
  static const sharedFolderName = 'Paylaşılan';

  /// Bir kutu bu kapsamda paylaşılıyor mu?
  bool allows(String box) => switch (mode) {
        ShareMode.sharedOnly => box == sharedBox,
        ShareMode.boxes => boxes == null || boxes!.contains(box),
      };

  /// Hiçbir kutu seçili değil mi (paylaşım açılsa da PC'de boş kök görünür)?
  bool get isEmpty =>
      mode == ShareMode.boxes && boxes != null && boxes!.isEmpty;

  ShareScope copyWith({ShareMode? mode, Set<String>? boxes}) => ShareScope(
        mode: mode ?? this.mode,
        boxes: boxes ?? this.boxes,
      );

  @override
  bool operator ==(Object other) =>
      other is ShareScope &&
      other.mode == mode &&
      _sameBoxes(other.boxes, boxes);

  @override
  int get hashCode => Object.hash(mode, boxes?.length);

  static bool _sameBoxes(Set<String>? a, Set<String>? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.length == b.length && a.containsAll(b);
  }
}
