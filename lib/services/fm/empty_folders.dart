import 'dart:async';
import 'dart:io';

import 'fs_events.dart';

/// **Boş klasör temizliği.**
///
/// ## Niye (2026-09-06 denetim turu)
/// Uygulamanın "yer aç" tarafı yinelenen dosyaları, çöp kutusunu ve büyük
/// dosyaları buluyor; **boş klasörleri hiç görmüyordu.** Oysa telefonda
/// bunlar kendiliğinden birikiyor: silinen bir uygulamanın geride bıraktığı
/// `Android/data/...`, WhatsApp'ın sildiği medyanın klasörü, "hepsini sil"
/// dedikten sonra kalan tarih klasörleri. Yer kazandırmazlar ama **listeyi
/// kirletirler**: kullanıcı dosyasını ararken onlarca boş klasörün içine
/// girip çıkıyor.
///
/// ## Kural: "boş" ne demek
/// Yalnız hiçbir dosya İÇERMEYEN klasör. İçinde yalnız başka boş klasörler
/// olan bir klasör de boştur (özyinelemeli): `Yedek/2024/Ocak` üçü de boşsa
/// üçü de listelenir ve **içten dışa** silinir.
///
/// Gizli dosyalar (`.nomedia`, `.thumbnails`) da DOSYADIR: içinde `.nomedia`
/// olan bir klasör boş sayılmaz. `.nomedia` bir karardır (galeri buraya
/// bakmasın) ve onu silmek kullanıcının galerisini değiştirir.
abstract final class EmptyFolders {
  /// Aramanın ineceği en fazla derinlik — bozuk bir bağlantı zincirinde
  /// sonsuza gitmeyi önler.
  static const maxDepth = 24;

  /// [root] altındaki boş klasörleri **içten dışa** sıralı döner.
  ///
  /// Sıra önemli: silme bu sırayla yapılınca üst klasör, altındakiler
  /// silindikten SONRA silinmeye çalışılır ve gerçekten boş olur.
  ///
  /// [root]'un kendisi listeye GİRMEZ: kullanıcı "İndirilenler klasörünü
  /// temizle" dediğinde İndirilenler'in kendisinin silinmesini beklemez.
  static Future<List<String>> find(
    String root, {
    void Function(String path)? onScan,
    bool Function()? isCancelled,
  }) async {
    final found = <String>[];
    var steps = 0;

    // Klasör boş mu? (Alt klasörleri önce gezilir; hepsi boşsa bu da boş.)
    Future<bool> walk(Directory dir, int depth) async {
      if (depth > maxDepth) return false;
      if (isCancelled?.call() ?? false) return false;
      List<FileSystemEntity> children;
      try {
        children = dir.listSync(followLinks: false);
      } catch (_) {
        // Okunamayan klasör (izin yok): boş SAYILMAZ. Silinemeyecek bir şeyi
        // listeye koymak kullanıcıya yalan söylemek olurdu.
        return false;
      }
      if (++steps % 200 == 0) await Future<void>.delayed(Duration.zero);
      onScan?.call(dir.path);
      var empty = true;
      for (final child in children) {
        if (child is Directory) {
          final childEmpty = await walk(child, depth + 1);
          if (childEmpty) {
            found.add(child.path);
          } else {
            empty = false;
          }
        } else {
          empty = false;
        }
      }
      return empty;
    }

    try {
      await walk(Directory(root), 0);
    } catch (_) {
      // Kök okunamıyorsa elimizdeki kadarıyla dönülür.
    }
    return found;
  }

  /// Verilen klasörleri siler; **kaçının silindiğini** döner.
  ///
  /// Silme `delete(recursive: false)`: klasör bu arada dolduysa (indirme
  /// bitti, kamera fotoğraf yazdı) sistem hata verir ve o klasör atlanır.
  /// `recursive: true` demek, tarama ile silme arasındaki saniyelerde gelen
  /// dosyayı sessizce silmek olurdu.
  static Future<int> deleteAll(
    List<String> paths, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    var deleted = 0;
    for (var i = 0; i < paths.length; i++) {
      if (isCancelled?.call() ?? false) break;
      try {
        Directory(paths[i]).deleteSync();
        deleted++;
      } catch (_) {}
      onProgress?.call(i + 1, paths.length);
    }
    if (deleted > 0) FsEvents.changed();
    return deleted;
  }
}
