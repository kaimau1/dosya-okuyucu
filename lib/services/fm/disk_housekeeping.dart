import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../scan_enhance.dart';
import 'pdf_edit_journal.dart';

/// **Disk önbelleği budama** — küçük resim, PDF kapağı, APK simgesi.
///
/// 2026-09-23 tasarım denetimi: üç önbellek ayrı ayrı budanıyordu ve üçünde
/// de sıralama karşılaştırıcısı her karşılaştırmada `statSync` çağırıyordu
/// (600 dosyada ~12 000 sistem çağrısı, ANA izlekte, ilk küçük resim
/// istendiği anda — listenin ilk kaydırması takılıyordu). PDF kapak
/// önbelleğinin ise HİÇ sınırı yoktu: her PDF'in her sürümü ve her boyu yeni
/// bir dosya olarak sonsuza dek birikiyordu.
///
/// Artık tek yol: her dosya BİR kez `stat`lanır ve iş izolatta yapılır.
abstract final class DiskCache {
  /// [dir] içindeki (isteğe bağlı olarak [extension] uzantılı) dosyaları
  /// [limit] adede indirir; en eski değişenler silinir. Silinen sayıyı döner.
  static int pruneSync(String dir, int limit, {String? extension}) {
    try {
      final root = Directory(dir);
      if (!root.existsSync()) return 0;
      final files = <(File, int)>[];
      for (final entity in root.listSync()) {
        if (entity is! File) continue;
        if (extension != null && !entity.path.endsWith(extension)) continue;
        try {
          files.add((entity, entity.statSync().modified.millisecondsSinceEpoch));
        } catch (_) {}
      }
      if (files.length <= limit) return 0;
      files.sort((a, b) => a.$2.compareTo(b.$2));
      var removed = 0;
      for (final (file, _) in files.take(files.length - limit)) {
        try {
          file.deleteSync();
          removed++;
        } catch (_) {}
      }
      return removed;
    } catch (_) {
      return 0;
    }
  }

  /// [pruneSync]'in izolatta çalışanı (ana izlek beklemez).
  static Future<int> prune(String dir, int limit, {String? extension}) async {
    try {
      return await Isolate.run(
          () => pruneSync(dir, limit, extension: extension));
    } catch (_) {
      return 0;
    }
  }
}

/// **Geçici dosya süpürücüsü.**
///
/// Tarama (her köşe düzeltmesi, döndürme, filtre YENİ bir dosya yazıyor —
/// görsel önbelleği eski kareyi göstermesin diye), OCR sayfa görüntüleri,
/// PDF düzenleyici çalışma kopyaları, arşiv önizlemeleri ve yakındaki cihaza
/// gönderme ZIP'leri geçici klasöre yazılıyor ve hiçbiri silinmiyordu.
/// Android önbelleği ancak depolama DARALINCA boşaltır; o zamana kadar
/// uygulamanın "önbellek" boyutu yüzlerce MB'a çıkabiliyordu.
///
/// **Yalnız BİZİM ürettiğimizi tanıdığımız** girdiler silinir (ad kalıbıyla):
/// geçici klasörde eklentilerin dosyaları da var (paylaşılan dosyanın kopyası,
/// seçicinin önbelleği) ve "son açılanlar" onlara işaret edebilir. Üç günden
/// yeni hiçbir şeye dokunulmaz — açık bir düzenleme ya da süren bir tarama
/// o kadar eski olamaz.
abstract final class TempSweep {
  static const maxAge = Duration(days: 3);

  /// Tamamen bize ait klasörlerin ad önekleri (`createTemp` ile açılanlar).
  static const ownDirPrefixes = [
    'dosya_okuyucu_edit', // görüntüleyici PDF düzenleme yedeği
    'pdf_editor', // PDF düzenleyici çalışma kopyası + geri alma noktaları
    'slayt-pdf', // slayt → PDF aktarımı
    'peer-zip', // yakındaki cihaza gönderme
  ];

  /// İçindekiler tek tek yaşlandırılan kalıcı klasörler.
  static const ownContainers = ['arsiv_onizleme'];

  static final RegExp _ownFile = RegExp(
    r'(^ocr_page_.+\.png$)|'
    r'(_(duzeltildi|donduruldu|duzlestirildi|'
    '${ScanFilter.values.map((f) => f.name).join('|')}'
    r')_\d+\.(png|jpg)$)',
  );

  /// Bu ad, bizim ürettiğimiz bir geçici girdi mi?
  static bool isOwn(String name, {required bool isDirectory}) {
    if (isDirectory) return ownDirPrefixes.any(name.startsWith);
    return _ownFile.hasMatch(name);
  }

  /// [root] altındaki eski geçici girdileri siler; silinen sayıyı döner.
  /// [keep] içindeki yollara (ve onları içeren klasörlere) dokunulmaz.
  static int sweepSync(String root, int nowMs, {Set<String> keep = const {}}) {
    final cutoff = nowMs - maxAge.inMilliseconds;
    var removed = 0;
    // Klasörün yaşı İÇİNDEKİ en yeni dosyadır: süren bir düzenleme oturumu
    // (geri alma noktası yazıldıkça) klasörü genç tutar. Boş klasörde
    // klasörün kendi zamanı.
    bool old(FileSystemEntity e) {
      try {
        if (e is Directory) {
          var newest = -1;
          for (final child in e.listSync(recursive: true)) {
            if (child is! File) continue;
            final t = child.statSync().modified.millisecondsSinceEpoch;
            if (t > newest) newest = t;
          }
          if (newest >= 0) return newest < cutoff;
        }
        return e.statSync().modified.millisecondsSinceEpoch < cutoff;
      } catch (_) {
        return false;
      }
    }

    bool kept(String path) =>
        keep.any((k) => k == path || p.isWithin(path, k));

    void delete(FileSystemEntity e) {
      try {
        e.deleteSync(recursive: true);
        removed++;
      } catch (_) {}
    }

    List<FileSystemEntity> list(Directory dir) {
      try {
        return dir.listSync();
      } catch (_) {
        return const [];
      }
    }

    for (final entity in list(Directory(root))) {
      final name = p.basename(entity.path);
      final isDir = entity is Directory;
      if (isDir && ownContainers.contains(name)) {
        for (final child in list(entity)) {
          if (!kept(child.path) && old(child)) delete(child);
        }
        continue;
      }
      if (!isOwn(name, isDirectory: isDir)) continue;
      if (kept(entity.path) || !old(entity)) continue;
      delete(entity);
    }
    return removed;
  }

  static bool _ran = false;

  /// Açılışta bir kez, izolatta. Önce yarıda kalmış PDF düzenlemeleri geri
  /// yüklenir (yedekleri süpürülmesin diye SIRA önemli).
  ///
  /// Geri yükleme HEMEN (kullanıcı dosyayı yeniden açmadan), süpürme ise
  /// [sweepDelay] sonra: ilk karelerle ve açılış taramasıyla yarışmasın.
  static Future<void> runOnce({
    Duration sweepDelay = const Duration(seconds: 20),
  }) async {
    if (_ran) return;
    _ran = true;
    try {
      PdfEditJournal.recover();
      await Future<void>.delayed(sweepDelay);
      final keep = PdfEditJournal.backups();
      final roots = <String>{Directory.systemTemp.path};
      try {
        roots.add((await getTemporaryDirectory()).path);
      } catch (_) {}
      final now = DateTime.now().millisecondsSinceEpoch;
      await Isolate.run(() {
        for (final root in roots) {
          sweepSync(root, now, keep: keep);
        }
      });
    } catch (_) {
      // Temizlik bir kolaylık; yapılamazsa uygulama yine çalışır.
    }
  }
}
