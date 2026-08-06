import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/drive_file.dart';

/// Drive'dan inen dosyaların **yerel önbelleği** (2026-08-06 kullanıcı
/// bulgusu: *"her açma istediğimde tekrar tekrar indiriyor"*).
///
/// Eskiden her açılış `drive/<ad>` yoluna koşulsuz yeniden indiriyordu: 40
/// MB'lık bir PDF her dokunuşta baştan iniyor, kullanıcı hem bekliyor hem
/// mobil veri harcıyordu.
///
/// ## Yol düzeni: `drive/<dosya kimliği>/<yerel ad>`
/// Kimlik ara klasör olarak kullanılıyor çünkü Drive'da **aynı adlı farklı
/// dosyalar** olabilir (ayrı klasörlerde iki "Rapor.pdf"). Düz `drive/<ad>`
/// düzeninde ikincisi birincinin üstüne yazardı ve kullanıcı yanlış belgeyi
/// açardı. Ad yine yolda duruyor ki paylaş/kaydet akışları düzgün ad görsün.
abstract final class DriveCache {
  /// Önbellek kökü (uygulamanın kendi destek klasörü altında).
  static String rootOf(String appSupportDir) => p.join(appSupportDir, 'drive');

  /// [file] için indirileceği klasör — dosya bunun içine `localName()` adıyla
  /// yazılır (`DriveService.download` zaten böyle yazıyor).
  static String dirFor(DriveFile file, String root) => p.join(root, file.id);

  static String pathFor(DriveFile file, String root) =>
      p.join(dirFor(file, root), file.localName());

  /// Önbellekteki kopya **kullanılabilir mi?** Saf karar fonksiyonu — birim
  /// testle sabitlenir, dosya sistemine `freshFile` sarmalıyor.
  ///
  /// Kurallar:
  /// * Dosya yoksa → indir.
  /// * Drive boyutu biliniyorsa (Google biçimlerinde gelmez) ve yerel boyut
  ///   tutmuyorsa → indir. Yarım kalmış/bozuk kopyayı bu yakalar.
  /// * Drive'daki değişiklik zamanı yerel dosyanınkinden yeniyse → indir
  ///   (dosya buluttan güncellenmiş).
  /// * Kalan her durumda önbellek geçerli.
  ///
  /// Yerel dosya Drive'dakinden YENİ olduğunda bilerek yeniden indirilmiyor:
  /// kullanıcının uygulama içinde yaptığı düzenleme sessizce ezilirdi.
  static bool isFresh({
    required bool exists,
    required int localSizeBytes,
    required int localModifiedMs,
    required int remoteSizeBytes,
    required int remoteModifiedMs,
  }) {
    if (!exists || localSizeBytes <= 0) return false;
    if (remoteSizeBytes > 0 && localSizeBytes != remoteSizeBytes) return false;
    if (remoteModifiedMs > 0 && localModifiedMs < remoteModifiedMs) return false;
    return true;
  }

  /// [file]'ın önbellekteki hazır kopyası (yoksa/eskiyse null).
  static File? freshFile(DriveFile file, String root) {
    final target = File(pathFor(file, root));
    if (!target.existsSync()) return null;
    final stat = target.statSync();
    final ok = isFresh(
      exists: true,
      localSizeBytes: stat.size,
      localModifiedMs: stat.modified.millisecondsSinceEpoch,
      remoteSizeBytes: file.sizeBytes,
      remoteModifiedMs: file.modifiedAtMs,
    );
    return ok ? target : null;
  }

  /// Önbellek üst sınırı. 400 MB: birkaç büyük PDF/sunum rahat sığar ama
  /// telefonun deposu sessizce dolmaz.
  static const maxBytes = 400 * 1024 * 1024;

  /// Sınır aşılmışsa **en eski dokunulan** klasörlerden başlayarak siler.
  /// İndirme bittikten sonra çağrılır; hata yutulur — temizlik başarısız diye
  /// kullanıcının açmak istediği dosya açılmamazlık etmemeli.
  static void prune(String root, {int limitBytes = maxBytes}) {
    try {
      final dir = Directory(root);
      if (!dir.existsSync()) return;
      final entries = <({Directory dir, int bytes, DateTime at})>[];
      var total = 0;
      for (final child in dir.listSync()) {
        if (child is File) {
          // Eski düz düzenin (`drive/<ad>`) artıkları — kimlik klasörü
          // gelmeden inen kopyalar. Artık hiç okunmuyorlar, yer tutmasınlar.
          try {
            child.deleteSync();
          } catch (_) {}
          continue;
        }
        if (child is! Directory) continue;
        var bytes = 0;
        var at = DateTime.fromMillisecondsSinceEpoch(0);
        for (final f in child.listSync(recursive: true)) {
          if (f is! File) continue;
          final s = f.statSync();
          bytes += s.size;
          if (s.modified.isAfter(at)) at = s.modified;
        }
        total += bytes;
        entries.add((dir: child, bytes: bytes, at: at));
      }
      if (total <= limitBytes) return;
      entries.sort((a, b) => a.at.compareTo(b.at)); // en eski önce
      for (final e in entries) {
        if (total <= limitBytes) break;
        try {
          e.dir.deleteSync(recursive: true);
          total -= e.bytes;
        } catch (_) {}
      }
    } catch (_) {}
  }
}
