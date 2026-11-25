import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import 'duplicate_finder.dart';
import 'fs_scan.dart';

/// Yer aç taramasının disk tarafı: **tek yürüyüş**, arka izlekte.
class CleanupWalkResult {
  /// Birimlerin `Download` klasörleri altındaki dosyalar.
  final List<FsEntry> downloads;

  /// Ana birimdeki boş klasörler, **içten dışa** (silme bu sırayla).
  final List<String> emptyFolders;

  /// Bayt bayt doğrulanmış kopya grupları.
  final List<DuplicateGroup> duplicates;

  const CleanupWalkResult({
    required this.downloads,
    required this.emptyFolders,
    required this.duplicates,
  });
}

/// KÖK NEDEN (2026-11-25, kullanıcı: *"Yer aç'ı hızlandır"*): çözümleme diski
/// ÜÇ kez geziyordu — İndirilenler (`FsScan.collect`), boş klasörler
/// (`EmptyFolders.find`, ana izlekte `listSync`) ve kopyalar
/// (`DuplicateFinder.scan`, tüm birimler). Üçü aynı ağacı okuyor; artık tek
/// yürüyüş üçünü birden çıkarır ve hepsi izolatta koşar (ana izlek boş
/// klasör ararken takılmaz).
///
/// Kurallar eskileriyle aynı:
/// - dosya listesi `walkFiles` kuralları ([FsScan.skipDirNames] atlanır,
///   bağlantı izlenmez, derinlik ≤ 24, `.pending-*` yok sayılır);
/// - boş klasör [EmptyFolders] tanımı: hiçbir dosya içermeyen (yalnız boş alt
///   klasörlü olan da boş), okunamayan klasör boş SAYILMAZ, kök listeye
///   girmez, yalnız ana birimde. Tek fark bilerek temkinli: atlanan sistem
///   klasörü (`.thumbnails`, çöp kutumuz…) içi görülmediği için "dolu"
///   sayılır — görmediğimiz şeyi silmeyiz.
abstract final class CleanupWalk {
  static Future<CleanupWalkResult> run(
    List<String> roots, {
    required String primaryRoot,
    int maxGroups = 300,
  }) async {
    try {
      return await Isolate.run(() => runSync(roots,
          primaryRoot: primaryRoot, maxGroups: maxGroups));
    } catch (_) {
      return runSync(roots, primaryRoot: primaryRoot, maxGroups: maxGroups);
    }
  }

  /// [run]'ın izolatsız hâli (birim testleri bunu çağırır).
  static CleanupWalkResult runSync(
    List<String> roots, {
    required String primaryRoot,
    int maxGroups = 300,
  }) {
    final files = <FsEntry>[];
    final downloads = <FsEntry>[];
    final empty = <String>[];
    final primary = p.normalize(primaryRoot);

    // Dönüş: klasör BOŞ mu (altında hiç dosya yok ve her yeri okunabildi).
    bool walk(String dirPath, int depth, bool collectEmpty, bool inDownload,
        String downloadDir) {
      if (depth > 24) return false;
      List<FileSystemEntity> children;
      try {
        children = Directory(dirPath).listSync(followLinks: false);
      } catch (_) {
        return false;
      }
      var isEmpty = true;
      for (final child in children) {
        final entry = FsEntry.fromEntity(child);
        if (entry.isLink) {
          isEmpty = false;
          continue;
        }
        if (entry.isDir) {
          if (FsScan.skipDirNames.contains(entry.name)) {
            isEmpty = false;
            continue;
          }
          final childEmpty = walk(child.path, depth + 1, collectEmpty,
              inDownload || child.path == downloadDir, downloadDir);
          if (childEmpty) {
            if (collectEmpty) empty.add(child.path);
          } else {
            isEmpty = false;
          }
          continue;
        }
        isEmpty = false;
        if (FsScan.isTransientMediaName(entry.name)) continue;
        files.add(entry);
        if (inDownload) downloads.add(entry);
      }
      return isEmpty;
    }

    for (final root in roots) {
      final collectEmpty = p.normalize(root) == primary;
      walk(root, 0, collectEmpty, false, p.join(root, 'Download'));
    }
    return CleanupWalkResult(
      downloads: downloads,
      emptyFolders: empty,
      duplicates: DuplicateFinder.groupSync(
          files, DuplicateFinder.defaultMinBytes, maxGroups),
    );
  }
}
