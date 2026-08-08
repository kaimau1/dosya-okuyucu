import 'dart:io';

/// Testin geçici klasörünü **hiçbir zaman testi kırmadan** siler.
///
/// **Niye var (KALANLAR: "Windows'ta kırık testler yerel doğrulamayı
/// köreltiyor"):** `tearDown` içinde çıplak `deleteSync(recursive: true)`
/// Windows'ta `FileSystemException` atıyor — dosya kolu henüz kapanmamış olur
/// (arşiv okuyucu, WebView, video denetleyicisi bir kolu geç bırakabiliyor).
/// O anda testin KENDİSİ çoktan geçmiştir; ama tearDown'daki istisna testi
/// KIRMIZI yakar. Sonuç: yerelde `flutter test` sürekli kırmızı döndüğü için
/// gerçek regresyon gürültüden ayırt edilemiyordu.
///
/// Temizlik bir doğrulama değildir: silinemezse işletim sistemi geçici klasörü
/// zaten kendisi toplar. Bu yüzden burada kısa bir yeniden deneme var ve
/// sonunda **sessizce** pes ediliyor.
void removeTempDir(FileSystemEntity? entity) {
  if (entity == null) return;
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      if (!entity.existsSync()) return;
      entity.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      // Kol hâlâ açık olabilir; kısa bir süre bekleyip yeniden dene.
      sleep(const Duration(milliseconds: 40));
    } catch (_) {
      return;
    }
  }
}
