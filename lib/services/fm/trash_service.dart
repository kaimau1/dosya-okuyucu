import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_ops.dart';
import 'fs_events.dart';

/// Çöp kutusundaki tek bir kayıt.
class TrashItem {
  /// Çöp klasöründeki gerçek yol (`…/.dosya-okuyucu-cop/files/<id>`).
  final String storedPath;

  /// Silinmeden önceki yol — geri yükleme buraya yapar.
  final String originalPath;
  final String name;
  final bool isDir;
  final int sizeBytes;
  final int deletedAtMs;

  /// Kaydın ait olduğu çöp klasörü (birim başına bir tane olabilir).
  final String trashDir;

  const TrashItem({
    required this.storedPath,
    required this.originalPath,
    required this.name,
    required this.isDir,
    required this.sizeBytes,
    required this.deletedAtMs,
    required this.trashDir,
  });

  Map<String, dynamic> toMap() => {
        'stored': p.basename(storedPath),
        'original': originalPath,
        'name': name,
        'isDir': isDir,
        'size': sizeBytes,
        'deletedAt': deletedAtMs,
      };

  static TrashItem? fromMap(Map<String, dynamic> m, String trashDir) {
    try {
      return TrashItem(
        storedPath: p.join(trashDir, 'files', m['stored'] as String),
        originalPath: m['original'] as String,
        name: m['name'] as String,
        isDir: m['isDir'] as bool? ?? false,
        sizeBytes: (m['size'] as num?)?.toInt() ?? 0,
        deletedAtMs: (m['deletedAt'] as num?)?.toInt() ?? 0,
        trashDir: trashDir,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Geri dönüşüm kutusu: silinen dosyalar önce buraya taşınır, kullanıcı geri
/// yükleyebilir ya da kalıcı silebilir.
///
/// **Karar — çöp klasörü uygulama verisinde DEĞİL, dosyanın kendi biriminde
/// (`/storage/emulated/0/.dosya-okuyucu-cop`):** `/data` ile `/storage` ayrı
/// bağlama noktalarıdır, aradaki `rename` başarısız olur → 2 GB'lık bir videoyu
/// çöpe atmak dosyayı baştan KOPYALARDI. Aynı birimde çöp = silme anında,
/// geri yükleme de anında.
class TrashService {
  /// Birim kökleri (dahili depolama, SD kart…).
  final List<String> volumeRoots;

  /// Birim tespit edilemeyen yollar için yedek çöp kökü (uygulama verisi).
  final String fallbackRoot;

  static const dirName = '.dosya-okuyucu-cop';
  static const _indexFile = 'index.json';

  const TrashService({required this.volumeRoots, required this.fallbackRoot});

  /// [path] hangi birimdeyse o birimin çöp klasörü.
  String trashDirFor(String path) {
    final normalized = p.normalize(path);
    for (final root in volumeRoots) {
      final r = p.normalize(root);
      if (normalized == r || normalized.startsWith('$r/')) {
        return p.join(r, dirName);
      }
    }
    return p.join(fallbackRoot, dirName);
  }

  List<String> get _allTrashDirs => {
        for (final r in volumeRoots) p.join(p.normalize(r), dirName),
        p.join(fallbackRoot, dirName),
      }.toList();

  /// Verilen yolları çöpe taşır.
  static var _counter = 0;
  Future<FmOpResult> moveToTrash(
    List<String> paths, {
    void Function(FmProgress)? onProgress,
  }) async {
    final errors = <String>[];
    var ok = 0;
    var done = 0;
    for (final path in paths) {
      final name = p.basename(path);
      onProgress?.call(FmProgress(done, paths.length, name));
      try {
        final trashDir = trashDirFor(path);
        final filesDir = Directory(p.join(trashDir, 'files'));
        await filesDir.create(recursive: true);
        // Çöp klasörünün kendisi medya taramasına girmesin.
        await _ensureNoMedia(trashDir);

        final id = '${DateTime.now().millisecondsSinceEpoch}'
            '-${_counter++}-${FileOps.sanitizeName(name)}';
        final stored = p.join(filesDir.path, id);
        final isDir = Directory(path).existsSync();
        final size = isDir ? 0 : (File(path).statSync().size);

        // Aynı birimde rename anında; olmazsa kopyala+sil'e düş.
        var moved = false;
        try {
          if (isDir) {
            await Directory(path).rename(stored);
          } else {
            await File(path).rename(stored);
          }
          moved = true;
        } on FileSystemException {
          moved = false;
        }
        if (!moved) {
          final r = await FileOps.moveAll([path], filesDir.path);
          if (r.hasError) throw FileSystemException(r.errors.first);
          // moveAll adı korur; id'ye çevir ki kayıt tutarlı olsun.
          final landed = p.join(filesDir.path, name);
          if (File(landed).existsSync()) {
            await File(landed).rename(stored);
          } else if (Directory(landed).existsSync()) {
            await Directory(landed).rename(stored);
          }
        }

        // GÜVENCE (2026-07-25 hatası): kaynak hâlâ yerindeyse çöp kaydı
        // OLUŞTURMA — yoksa dosya hem klasörde hem çöpte görünür. Böyle bir
        // durumda çöpe düşen kopyayı da temizleyip hatayı bildiriyoruz.
        if (File(path).existsSync() || Directory(path).existsSync()) {
          try {
            if (isDir) {
              Directory(stored).deleteSync(recursive: true);
            } else {
              File(stored).deleteSync();
            }
          } catch (_) {}
          throw const FileSystemException(
              'dosya taşınamadı (yerinde kaldı), çöp kaydı oluşturulmadı');
        }

        await _appendIndex(
          trashDir,
          TrashItem(
            storedPath: stored,
            originalPath: path,
            name: name,
            isDir: isDir,
            sizeBytes: size,
            deletedAtMs: DateTime.now().millisecondsSinceEpoch,
            trashDir: trashDir,
          ),
        );
        ok++;
      } catch (e) {
        errors.add('$name: $e');
      }
      done++;
    }
    onProgress?.call(FmProgress(done, paths.length, ''));
    if (ok > 0) FsEvents.changed();
    return FmOpResult(succeeded: ok, errors: errors);
  }

  /// Çöpteki tüm kayıtlar (en yeni önce). Diskte karşılığı kalmamış kayıtlar
  /// (kullanıcı klasörü elle silmişse) listeden düşer.
  Future<List<TrashItem>> list() async {
    final out = <TrashItem>[];
    for (final dir in _allTrashDirs) {
      for (final item in await _readIndex(dir)) {
        if (File(item.storedPath).existsSync() ||
            Directory(item.storedPath).existsSync()) {
          out.add(item);
        }
      }
    }
    out.sort((a, b) => b.deletedAtMs.compareTo(a.deletedAtMs));
    return out;
  }

  /// Kaydı eski yerine geri yükler. Eski yol doluysa `" (1)"` ekiyle.
  Future<String> restore(TrashItem item) async {
    final parent = Directory(p.dirname(item.originalPath));
    if (!parent.existsSync()) await parent.create(recursive: true);
    final target = FileOps.uniquePath(item.originalPath);
    try {
      if (item.isDir) {
        await Directory(item.storedPath).rename(target);
      } else {
        await File(item.storedPath).rename(target);
      }
    } on FileSystemException {
      final r = await FileOps.moveAll([item.storedPath], p.dirname(target));
      if (r.hasError) throw FileSystemException(r.errors.first);
    }
    await _removeFromIndex(item);
    FsEvents.changed();
    return target;
  }

  Future<void> deleteForever(TrashItem item) async {
    try {
      if (item.isDir) {
        await Directory(item.storedPath).delete(recursive: true);
      } else {
        await File(item.storedPath).delete();
      }
    } catch (_) {
      // dosya zaten yoksa kayıt yine de düşsün
    }
    await _removeFromIndex(item);
    FsEvents.changed();
  }

  /// [days] günden eski kayıtları kalıcı siler (ayarlardaki otomatik
  /// temizleme). Silinen öğe sayısını döndürür.
  Future<int> purgeOlderThan(int days) async {
    if (days <= 0) return 0;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    var removed = 0;
    for (final item in await list()) {
      if (item.deletedAtMs > 0 && item.deletedAtMs < cutoff) {
        await deleteForever(item);
        removed++;
      }
    }
    return removed;
  }

  /// Çöp kutusunu boşaltır. [onProgress] verilirse her öğede ilerleme
  /// bildirilir — kullanıcı isteği (2026-07-25): "çöp kutusu boşaltılırken
  /// sessizlik oluyor, ne olduğu belli değil".
  ///
  /// Silinen öğe sayısı ve (varsa) hatalar döner; kısmi başarı sessizce
  /// yutulmaz.
  Future<FmOpResult> empty({
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final items = await list();
    final errors = <String>[];
    var ok = 0;
    var done = 0;
    for (final item in items) {
      if (isCancelled?.call() ?? false) {
        return FmOpResult(succeeded: ok, errors: errors, cancelled: true);
      }
      onProgress?.call(FmProgress(done, items.length, item.name));
      try {
        await deleteForever(item);
        ok++;
      } catch (e) {
        errors.add('${item.name}: $e');
      }
      done++;
    }
    onProgress?.call(FmProgress(done, items.length, ''));
    return FmOpResult(succeeded: ok, errors: errors);
  }

  /// Çöpteki toplam boyut (kayıtlardan; klasörler 0 sayılır).
  Future<int> totalBytes() async {
    var sum = 0;
    for (final item in await list()) {
      sum += item.sizeBytes;
    }
    return sum;
  }

  // ── index.json ─────────────────────────────────────────────────────────

  Future<List<TrashItem>> _readIndex(String trashDir) async {
    final file = File(p.join(trashDir, _indexFile));
    if (!file.existsSync()) return const [];
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => TrashItem.fromMap(m.cast<String, dynamic>(), trashDir))
          .whereType<TrashItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeIndex(String trashDir, List<TrashItem> items) async {
    final file = File(p.join(trashDir, _indexFile));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(items.map((i) => i.toMap()).toList()),
        flush: true);
  }

  Future<void> _appendIndex(String trashDir, TrashItem item) async {
    final items = [...await _readIndex(trashDir), item];
    await _writeIndex(trashDir, items);
  }

  Future<void> _removeFromIndex(TrashItem item) async {
    // _readIndex sabit (değiştirilemez) liste dönebilir → kopyala.
    final items = [...await _readIndex(item.trashDir)]
      ..removeWhere((i) => i.storedPath == item.storedPath);
    await _writeIndex(item.trashDir, items);
  }

  /// `.nomedia`: galeri/müzik uygulamaları çöpteki dosyaları göstermesin.
  Future<void> _ensureNoMedia(String trashDir) async {
    final marker = File(p.join(trashDir, '.nomedia'));
    if (!marker.existsSync()) await marker.create(recursive: true);
  }
}
