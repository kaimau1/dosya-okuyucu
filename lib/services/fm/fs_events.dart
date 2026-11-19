import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'media_scan.dart';

/// Dosya sistemi değişiklik sinyali.
///
/// **Niye var (2026-07-25 hatası):** kullanıcı bir dosyayı silince pano
/// (depolama panosu) eski sayıları göstermeye devam ediyordu — tarama sonucu
/// süreç boyunca önbellekli ve kimse "artık geçersiz" demiyordu. Artık her
/// dosya işlemi (sil / kopyala / taşı / yeniden adlandır / çıkar / sıkıştır)
/// bu sayacı artırır; ekranlar dinleyip kendini tazeler.
abstract final class FsEvents {
  /// Her değişiklikte artan sürüm numarası.
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  /// [paths] verilirse (değişen dosyaların eski ve yeni yolları) Android 10
  /// ve öncesinde galeriye de bildirilir — bkz. [MediaScan].
  /// Bu sürüm numaralı değişikliği arama dizini ZATEN işledi mi (Faz 41 /
  /// 8 perf: artımlı dizin)? İşlediyse dizin "bayat" sayılmaz, tam yeniden
  /// kurulum gerekmez.
  static int indexedVersion = -1;

  /// [indexed]: çağıran değişikliği arama dizinine kendisi yazdı
  /// (`SearchIndex.applyChanges`).
  static void changed([Iterable<String> paths = const [], bool indexed = false]) {
    if (indexed) indexedVersion = version.value + 1;
    version.value = version.value + 1;
    MediaScan.request(paths);
  }

  /// Uygulama GERÇEKTEN arkaya gidip (başka uygulama, ana ekran, ekran
  /// kapandı) öne döndüğünde artar.
  ///
  /// **KÖK NEDEN (kullanıcı 2026-11-17):** *"Claude'dan PDF indirdim,
  /// İndirilenler'e kaydedildi dedi ama ne İndirilenler'de ne Yeni
  /// dosyalar'da görünüyordu"* — Notlar'ın "Farklı kaydet"iyle inen PDF de
  /// öyle. [version] yalnız UYGULAMA İÇİNDEKİ işlemlerde artıyor; başka
  /// uygulamanın yazdığı dosyayı kimse haber vermiyordu. İndirilenler sekmesi
  /// ve gezgin ayakta kaldıkları için (IndexedStack / yığındaki sayfa) ilk
  /// açılıştaki listeyi gösteriyordu; Yeni dosyalar 20 sn kısıtına takılıyordu.
  /// Uygulamanın kendi "İndir"i [changed] dediği için yalnız o yol
  /// görünüyordu. Artık ayakta duran listeler bunu dinleyip sessizce tazelenir.
  ///
  /// *Niye `resumed` değil:* izin penceresi, paylaşım sayfası, bildirim perdesi
  /// de `resumed` üretir; onlar dosya eklemez. Yalnız `hidden`dan dönüş sayılır.
  static final ValueNotifier<int> returned = ValueNotifier<int>(0);

  static bool _away = false;

  /// Uygulama görünmez oldu (`hidden`) — main.dart'taki yaşam döngüsü kancası.
  static void wentAway() => _away = true;

  /// Uygulama öne geldi (`resumed`); arada gerçekten arkadaysa [returned]
  /// artar, yoksa (yalnız `inactive` olduysa) hiçbir şey olmaz.
  static void cameBack() {
    if (!_away) return;
    _away = false;
    returned.value = returned.value + 1;
  }

  /// Küçük resmi/önizlemesi açılamayan bir dosyayı bildirir.
  ///
  /// **Niye gerekli (2026-07-27 kullanıcı ekran görüntüsü):** listeler yalnız
  /// UYGULAMA İÇİNDEN silme olunca tazeleniyordu. Dosyayı Galeri ya da
  /// WhatsApp temizliği silince kimse haber vermiyor; kayıt listede kalıyor ve
  /// mor "resim" rozetine düşüyordu — kullanıcı olmayan dosyaların hayaletini
  /// görüyordu. Artık küçük resim açılamayınca buraya bildiriliyor.
  ///
  /// İki koruma var:
  /// * dosya GERÇEKTEN yoksa listeden düşürülür — bozuk ama duran bir dosya
  ///   (desteklenmeyen kodek) listede kalmalı, silinmiş gibi davranmak yanlış
  ///   olurdu;
  /// * bildirimler kare sonuna kadar biriktirilip TEK sinyale indirgenir.
  ///   800 fotoğraflı bir ızgarada her hücrenin ayrı ayrı tazeleme tetiklemesi
  ///   uygulamayı kilitlerdi.
  static void reportUnreadable(String path) {
    if (!_unreadable.add(path)) return;
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => _flush());
  }

  static final Set<String> _unreadable = {};
  static bool _flushScheduled = false;

  static void _flush() {
    _flushScheduled = false;
    final reported = _unreadable.toList();
    _unreadable.clear();
    final gone = reported.where((p) => !File(p).existsSync());
    if (gone.isEmpty) return;
    changed();
  }
}
