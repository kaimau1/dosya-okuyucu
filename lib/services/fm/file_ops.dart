import 'dart:io';

import 'package:path/path.dart' as p;

import 'fs_scan.dart';

/// Hedefte aynı adlı dosya varsa ne yapılacağı.
enum FmConflict {
  /// Yeni ad ver: `rapor.pdf` → `rapor (1).pdf` (varsayılan, veri kaybı yok).
  rename,

  /// Hedefi üzerine yaz.
  overwrite,

  /// Bu dosyayı atla.
  skip,
}

/// Uzun süren bir işlemin anlık durumu (ilerleme çubuğu için).
class FmProgress {
  final int done;
  final int total;
  final String currentName;
  const FmProgress(this.done, this.total, this.currentName);

  double get fraction => total <= 0 ? 0 : (done / total).clamp(0, 1).toDouble();
}

/// Bir toplu işlemin sonucu. Hata TEK dosyada olsa bile işlem devam eder;
/// kullanıcıya sonda özet gösterilir (yarım kalan kopyalama en kötü sonuç).
class FmOpResult {
  final int succeeded;
  final int skipped;
  final List<String> errors;
  final bool cancelled;
  const FmOpResult({
    this.succeeded = 0,
    this.skipped = 0,
    this.errors = const [],
    this.cancelled = false,
  });

  bool get hasError => errors.isNotEmpty;
}

/// Dosya işlemleri: kopyala / taşı / sil / yeniden adlandır / oluştur.
///
/// Saf `dart:io` — Flutter bağımlılığı yok, geçici klasörle birim testi
/// yazılabilir (`test/fm_file_ops_test.dart`).
abstract final class FileOps {
  /// Hedef yol doluysa boşta olan ilk `" (n)"` ekli adı üretir.
  /// `rapor.pdf` → `rapor (1).pdf` → `rapor (2).pdf`; klasörde uzantı yok.
  static String uniquePath(String destPath) {
    if (!_exists(destPath)) return destPath;
    final dir = p.dirname(destPath);
    final base = p.basenameWithoutExtension(destPath);
    final ext = p.extension(destPath); // baştaki nokta dahil
    for (var i = 1; i < 10000; i++) {
      final candidate = p.join(dir, '$base ($i)$ext');
      if (!_exists(candidate)) return candidate;
    }
    // Pratikte ulaşılmaz; yine de veri ezmemek için zaman damgası ekle.
    return p.join(dir, '$base-${DateTime.now().millisecondsSinceEpoch}$ext');
  }

  static bool _exists(String path) =>
      File(path).existsSync() || Directory(path).existsSync();

  /// Kaynakları [destDir] içine kopyalar.
  static Future<FmOpResult> copyAll(
    List<String> sources,
    String destDir, {
    FmConflict conflict = FmConflict.rename,
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) =>
      _transfer(sources, destDir,
          move: false,
          conflict: conflict,
          onProgress: onProgress,
          isCancelled: isCancelled);

  /// Kaynakları [destDir] içine taşır. Aynı bölümde `rename` ile anında;
  /// farklı bölümde (SD kart ↔ dahili) kopyala+sil ile.
  static Future<FmOpResult> moveAll(
    List<String> sources,
    String destDir, {
    FmConflict conflict = FmConflict.rename,
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) =>
      _transfer(sources, destDir,
          move: true,
          conflict: conflict,
          onProgress: onProgress,
          isCancelled: isCancelled);

  static Future<FmOpResult> _transfer(
    List<String> sources,
    String destDir, {
    required bool move,
    required FmConflict conflict,
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final errors = <String>[];
    var done = 0;
    var skipped = 0;
    var succeeded = 0;
    final total = _countFiles(sources);

    for (final src in sources) {
      if (isCancelled?.call() ?? false) {
        return FmOpResult(
            succeeded: succeeded,
            skipped: skipped,
            errors: errors,
            cancelled: true);
      }
      final name = p.basename(src);
      // Klasörü kendi içine taşıma/kopyalama sonsuz özyinelemedir.
      if (FsPaths.isInside(src, destDir)) {
        errors.add('$name: klasör kendi içine taşınamaz');
        continue;
      }
      var dest = p.join(destDir, name);
      if (p.normalize(src) == p.normalize(dest)) {
        // Aynı klasöre kopyalama → kopya üret ("rapor (1).pdf").
        if (move) {
          skipped++;
          continue;
        }
        dest = uniquePath(dest);
      }
      try {
        await _transferOne(
          src,
          dest,
          move: move,
          conflict: conflict,
          onFile: (fileName) {
            done++;
            onProgress?.call(FmProgress(done, total, fileName));
          },
          isCancelled: isCancelled,
          onSkip: () => skipped++,
        );
        succeeded++;
      } catch (e) {
        errors.add('$name: ${_msg(e)}');
      }
    }
    return FmOpResult(
        succeeded: succeeded, skipped: skipped, errors: errors);
  }

  static Future<void> _transferOne(
    String src,
    String dest, {
    required bool move,
    required FmConflict conflict,
    required void Function(String) onFile,
    required void Function() onSkip,
    bool Function()? isCancelled,
  }) async {
    final srcDir = Directory(src);
    final isDir = srcDir.existsSync();

    if (isDir) {
      // Hızlı yol: aynı bölümde, hedef boşken klasörün tamamı tek `rename` ile
      // taşınır (binlerce dosyayı tek tek kopyalamaya gerek yok).
      if (move && !_exists(dest)) {
        try {
          await srcDir.rename(dest);
          onFile(p.basename(src));
          return;
        } on FileSystemException {
          // farklı bölüm → aşağıdaki normal yol
        }
      }
      // Klasör: hedef varsa BİRLEŞTİR (içerik tek tek kopyalanır) — hedefi
      // silip yeniden yazmak, hedefteki başka dosyaları kaybettirirdi.
      final target = Directory(_exists(dest) && conflict == FmConflict.rename
          ? uniquePath(dest)
          : dest);
      await target.create(recursive: true);
      for (final child in srcDir.listSync(followLinks: false)) {
        if (isCancelled?.call() ?? false) return;
        await _transferOne(
          child.path,
          p.join(target.path, p.basename(child.path)),
          move: move,
          conflict: conflict,
          onFile: onFile,
          onSkip: onSkip,
          isCancelled: isCancelled,
        );
      }
      if (move) {
        try {
          await srcDir.delete(recursive: true);
        } catch (_) {
          // içeride kopyalanamayan dosya kaldıysa kaynak durur — veri kaybı yok
        }
      }
      return;
    }

    final file = File(src);
    if (!file.existsSync()) throw const FileSystemException('kaynak bulunamadı');

    var target = dest;
    if (_exists(dest)) {
      switch (conflict) {
        case FmConflict.skip:
          onSkip();
          return;
        case FmConflict.rename:
          target = uniquePath(dest);
        case FmConflict.overwrite:
          try {
            File(dest).deleteSync();
          } catch (_) {}
      }
    }

    onFile(p.basename(src));
    if (move) {
      try {
        await file.rename(target); // aynı bölümde anında
        return;
      } on FileSystemException {
        // farklı bölüm (SD kart / OTG): kopyala + sil
      }
      await file.copy(target);
      await file.delete();
    } else {
      await file.copy(target);
    }
  }

  /// Kalıcı silme (çöp kutusuna göndermeden). Klasörler özyinelemeli silinir.
  static Future<FmOpResult> deleteAll(
    List<String> paths, {
    void Function(FmProgress)? onProgress,
  }) async {
    final errors = <String>[];
    var done = 0;
    var ok = 0;
    for (final path in paths) {
      final name = p.basename(path);
      onProgress?.call(FmProgress(done, paths.length, name));
      try {
        final dir = Directory(path);
        if (dir.existsSync()) {
          await dir.delete(recursive: true);
        } else {
          await File(path).delete();
        }
        ok++;
      } catch (e) {
        errors.add('$name: ${_msg(e)}');
      }
      done++;
    }
    onProgress?.call(FmProgress(done, paths.length, ''));
    return FmOpResult(succeeded: ok, errors: errors);
  }

  /// Yeniden adlandırır ve yeni yolu döndürür.
  static Future<String> rename(String path, String newName) async {
    final clean = sanitizeName(newName);
    if (clean.isEmpty) throw const FileSystemException('ad boş olamaz');
    final target = p.join(p.dirname(path), clean);
    if (p.normalize(target) == p.normalize(path)) return path;
    if (_exists(target)) {
      throw const FileSystemException('bu adda bir öğe zaten var');
    }
    final dir = Directory(path);
    if (dir.existsSync()) {
      final renamed = await dir.rename(target);
      return renamed.path;
    }
    final renamed = await File(path).rename(target);
    return renamed.path;
  }

  static Future<String> createFolder(String parent, String name) async {
    final clean = sanitizeName(name);
    if (clean.isEmpty) throw const FileSystemException('ad boş olamaz');
    final target = p.join(parent, clean);
    if (_exists(target)) {
      throw const FileSystemException('bu adda bir öğe zaten var');
    }
    await Directory(target).create(recursive: true);
    return target;
  }

  static Future<String> createFile(String parent, String name,
      {String content = ''}) async {
    final clean = sanitizeName(name);
    if (clean.isEmpty) throw const FileSystemException('ad boş olamaz');
    final target = p.join(parent, clean);
    if (_exists(target)) {
      throw const FileSystemException('bu adda bir öğe zaten var');
    }
    await File(target).writeAsString(content);
    return target;
  }

  /// Dosya adından yol ayracı ve kontrol karakterlerini temizler. Kullanıcı
  /// "a/b" yazarsa yanlışlıkla başka klasöre yazmayı engeller.
  static String sanitizeName(String name) => name
      .trim()
      .replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'^\.+$'), '');

  /// İlerleme yüzdesi için dosya sayısı (klasörler özyinelemeli sayılır).
  /// Çok büyük ağaçlarda sayım da pahalıdır → 20 bin dosyada durur, ilerleme
  /// çubuğu yaklaşık olur (işlemin kendisi tam yapılır).
  static int _countFiles(List<String> sources) {
    var n = 0;
    void walk(String path, int depth) {
      if (n >= 20000 || depth > 24) return;
      final dir = Directory(path);
      if (dir.existsSync()) {
        List<FileSystemEntity> children;
        try {
          children = dir.listSync(followLinks: false);
        } catch (_) {
          return;
        }
        for (final c in children) {
          walk(c.path, depth + 1);
        }
      } else {
        n++;
      }
    }

    for (final s in sources) {
      walk(s, 0);
    }
    return n == 0 ? sources.length : n;
  }

  static String _msg(Object e) {
    if (e is FileSystemException) {
      return e.osError?.message ?? e.message;
    }
    return e.toString();
  }
}
