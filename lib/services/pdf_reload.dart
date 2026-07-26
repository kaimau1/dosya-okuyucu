import 'package:pdfrx/pdfrx.dart';

/// Diske yazılmış bir PDF'i **açık görüntüleyicide** tazeler.
///
/// KÖK NEDEN (2026-07-26, "PDF'te vurgulama çalışmıyor" bulgusu):
/// pdfrx yüklenmiş belgeleri `PdfDocumentRef._listenables` adlı **statik**
/// haritada tutar ve `PdfDocumentRefFile`'ın eşitliği YALNIZ dosya yoluna bakar.
/// Widget'ı `ValueKey` değiştirip yeniden bağlamak (remount) işe yaramaz:
/// Flutter önce yeni elemanı kurar (`initState` → `resolveListenable`), eskinin
/// `dispose`'u ise karenin sonunda çalışır → yeni widget haritadaki ESKİ
/// listenable'ı bulur, `load()` "zaten yüklendi" deyip erken döner ve ekranda
/// dosyanın eski hâli kalır. Vurgu/imza dosyaya yazılıyordu ama görünmüyordu.
///
/// Çözüm: aynı listenable'ı bulup `load(forceReload: true)` ile yeniden
/// okutmak. Bu, dinleyicileri (yani açık görüntüleyiciyi) uyarır; widget'ı
/// yeniden bağlamaya gerek kalmaz — üstelik kullanıcı **aynı sayfada** kalır.
class PdfReload {
  const PdfReload._();

  /// [path] dosyasını, açık olan tüm pdfrx görüntüleyicilerinde yeniden okutur.
  ///
  /// Görüntüleyici kapalıysa hiçbir şey yapmaz (geçici kaydı da temizler):
  /// dinleyicisi olmayan bir kayıt haritada asılı kalırsa belge boşuna bellekte
  /// tutulurdu — bu yüzden kendi dinleyicimizi ekleyip iş bitince kaldırıyoruz.
  static Future<void> reloadFile(String path) async {
    final listenable = PdfDocumentRefFile(path).resolveListenable();
    // Yükleme sırasında kayıt serbest bırakılmasın diye geçici dinleyici.
    final removeListener = listenable.addListener(_noop);
    try {
      await listenable.load(forceReload: true);
    } finally {
      removeListener();
    }
  }

  static void _noop() {}
}
