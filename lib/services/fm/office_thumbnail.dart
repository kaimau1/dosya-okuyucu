import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'disk_housekeeping.dart';
import 'thumbnail_cache.dart';

/// **Slayt / Excel / Word dosyalarının liste önizlemesi** (2026-11-04).
///
/// Kullanıcı: *"slayt ve Excel iyileştirmeleri, özellikle slaytta ön izleme
/// kısmında"*. Listelerde PDF kapağı görünüyordu ama sunum, tablo ve Word
/// dosyaları hep aynı simgeydi. Office (ve LibreOffice) dosyayı kaydederken
/// içine hazır bir önizleme resmi koyar — PowerPoint ilk slaytın resmini
/// varsayılan olarak yazar. Burada o resim zip'ten çıkarılıp diskte
/// önbelleğe alınır; belge AÇILMAZ, çizilmez (liste kaymasın).
///
/// Sınırlar: resmi olmayan dosya (çoğu Excel, Google'dan inen belgeler) simge
/// olarak kalır ve bir daha denenmez; EMF/WMF önizleme (eski Word) çizilemez.
abstract final class OfficeThumbnail {
  /// Zip tabanlı Office / ODF uzantıları.
  static const extensions = {
    'pptx', 'pptm', 'ppsx', 'potx', //
    'xlsx', 'xlsm', 'xltx', //
    'docx', 'docm', 'dotx', //
    'odp', 'ods', 'odt',
  };

  static bool supports(String extension) =>
      extensions.contains(extension.toLowerCase());

  /// Aranan girdiler, öncelik sırasıyla (OOXML, sonra ODF).
  static const _entries = [
    'docprops/thumbnail.jpeg',
    'docprops/thumbnail.jpg',
    'docprops/thumbnail.png',
    'thumbnails/thumbnail.png',
  ];

  static final Map<String, Future<String?>> _inFlight = {};
  static final Set<String> _failed = <String>{};
  static Directory? _dir;

  /// Diskte tutulan en çok önizleme.
  static const cacheLimit = 400;

  @visibleForTesting
  static void debugReset() {
    _inFlight.clear();
    _failed.clear();
    _dir = null;
  }

  /// Zip'teki gömülü önizleme resminin baytları; yoksa null. Dosyanın tamamı
  /// belleğe alınmaz (`InputFileStream`: yalnız zip dizini + o girdi).
  static Uint8List? readEmbedded(String path) {
    InputFileStream? input;
    try {
      input = InputFileStream(path);
      final archive = ZipDecoder().decodeStream(input);
      for (final wanted in _entries) {
        for (final entry in archive.files) {
          if (!entry.isFile || entry.name.toLowerCase() != wanted) continue;
          final bytes = entry.content;
          if (bytes.isNotEmpty) return Uint8List.fromList(bytes);
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      try {
        input?.closeSync();
      } catch (_) {}
    }
  }

  /// [path]'in önizleme resmi (diskteki yolu); yoksa ya da çıkarılamazsa null.
  static Future<String?> forOffice(String path) {
    if (_failed.contains(path)) return Future.value(null);
    final existing = _inFlight[path];
    if (existing != null) return existing;
    final future = _generate(path);
    _inFlight[path] = future;
    future.whenComplete(() => _inFlight.remove(path));
    return future;
  }

  static Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'office_thumbs'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    _dir = dir;
    unawaited(DiskCache.prune(dir.path, cacheLimit));
    return dir;
  }

  static Future<String?> _generate(String path) async {
    try {
      final stat = File(path).statSync();
      if (stat.type != FileSystemEntityType.file) return _fail(path);
      final dir = await _cacheDir();
      // Uzantı .img: içerik JPEG ya da PNG olabilir, çözücü baytlara bakar.
      final dest = p.join(
          dir.path,
          ThumbnailCache.cacheName(
                  path, stat.modified.millisecondsSinceEpoch, 0)
              .replaceAll('.jpg', '.img'));
      if (File(dest).existsSync()) return dest;
      final bytes = await Isolate.run(() => readEmbedded(path));
      if (bytes == null) return _fail(path);
      await File(dest).writeAsBytes(bytes, flush: true);
      return dest;
    } catch (_) {
      return _fail(path);
    }
  }

  static String? _fail(String path) {
    if (_failed.length > 512) _failed.clear();
    _failed.add(path);
    return null;
  }
}
