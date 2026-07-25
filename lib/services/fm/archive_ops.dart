import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'file_ops.dart';

/// Arşiv işlemleri: sıkıştır (.zip) ve çıkar (.zip/.tar/.gz/.tgz/.bz2).
///
/// `archive` paketi zaten bağımlılıkta (OOXML okuma/yazma için) — dosya
/// yöneticisi için YENİ bağımlılık eklenmedi. RAR/7z bilinçli kapsam dışı:
/// saf Dart çözücüleri yok; o dosyalar "başka uygulamayla aç"a düşer.
abstract final class ArchiveOps {
  static const supportedExtract = {
    'zip', 'tar', 'gz', 'tgz', 'bz2', 'jar', 'apks', 'xapk',
  };

  static bool canExtract(String path) =>
      supportedExtract.contains(p.extension(path).replaceFirst('.', '')
          .toLowerCase());

  /// [paths]'i tek bir .zip'e sıkıştırır ve zip'in yolunu döndürür.
  ///
  /// Akış tabanlı `ZipFileEncoder` kullanılır (tüm arşivi belleğe almaz) —
  /// telefonda 1 GB'lık klasör sıkıştırılırken bellek patlamasın.
  static Future<String> zip(
    List<String> paths,
    String destDir, {
    String? archiveName,
    void Function(FmProgress)? onProgress,
  }) async {
    if (paths.isEmpty) throw const FileSystemException('sıkıştırılacak öğe yok');
    final base = archiveName != null && archiveName.trim().isNotEmpty
        ? FileOps.sanitizeName(archiveName)
        : (paths.length == 1
            ? p.basenameWithoutExtension(paths.first)
            : 'arsiv');
    final target = FileOps.uniquePath(p.join(destDir, '$base.zip'));

    final encoder = ZipFileEncoder();
    encoder.create(target);
    try {
      var done = 0;
      for (final path in paths) {
        onProgress?.call(FmProgress(done, paths.length, p.basename(path)));
        final dir = Directory(path);
        if (dir.existsSync()) {
          await encoder.addDirectory(dir);
        } else {
          await encoder.addFile(File(path));
        }
        done++;
      }
      onProgress?.call(FmProgress(done, paths.length, ''));
    } finally {
      await encoder.close();
    }
    return target;
  }

  /// Arşivi, adıyla aynı isimli yeni bir klasöre çıkarır ve klasörü döndürür.
  /// Hedef klasör doluysa `" (1)"` eklenir (mevcut dosyaların üstüne yazılmaz).
  static Future<String> extract(String archivePath, {String? destDir}) async {
    if (!canExtract(archivePath)) {
      throw const FileSystemException(
          'bu arşiv biçimi cihazda açılamıyor (RAR/7z desteklenmiyor)');
    }
    final parent = destDir ?? p.dirname(archivePath);
    var name = p.basenameWithoutExtension(archivePath);
    // "yedek.tar.gz" → "yedek" (çift uzantı)
    if (p.extension(name).toLowerCase() == '.tar') {
      name = p.basenameWithoutExtension(name);
    }
    final target = FileOps.uniquePath(p.join(parent, name));
    await Directory(target).create(recursive: true);
    // extractFileToDisk zip-slip'e karşı korumalı (isWithinOutputPath).
    await extractFileToDisk(archivePath, target);
    return target;
  }

  /// Arşivin içindekileri (yol listesi) okur — çıkarmadan önizleme için.
  /// Yalnızca .zip; hata durumunda boş liste döner.
  static Future<List<String>> peekZip(String archivePath, {int limit = 500}) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      return archive.files.take(limit).map((f) => f.name).toList();
    } catch (_) {
      return const [];
    }
  }
}
