import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import 'fs_scan.dart';

/// Bir klasörün DOĞRUDAN çocuğu: alt klasör ya da dosya, **altındaki her şey
/// dahil** toplam boyutuyla.
class FolderUsage {
  final String path;
  final String name;
  final bool isDir;

  /// Altındaki tüm dosyaların toplamı (dosyada kendi boyutu).
  final int bytes;

  /// Altındaki dosya sayısı (dosyada 1).
  final int files;

  const FolderUsage({
    required this.path,
    required this.name,
    required this.isDir,
    required this.bytes,
    required this.files,
  });
}

/// Bir klasörün dökümü: çocukları (büyükten küçüğe) + toplamı.
class FolderBreakdown {
  final String root;
  final List<FolderUsage> children;
  final int totalBytes;
  final int totalFiles;

  const FolderBreakdown({
    required this.root,
    required this.children,
    required this.totalBytes,
    required this.totalFiles,
  });

  static const empty =
      FolderBreakdown(root: '', children: [], totalBytes: 0, totalFiles: 0);
}

/// **Klasör haritası** — "hangi klasör ne kadar yer kaplıyor" sorusunun
/// cevabı, klasör klasör inilebilen hâliyle.
///
/// Kullanıcı isteği (2026-08-17, ekran görüntüsü): bellek analizinde başka bir
/// programdaki gibi *"klasörler boyuta göre sıralı, yanında oransal çubuk ve
/// yüzde"* görünsün. Bizim analiz ekranı yalnız **türe göre** (Videolar,
/// Görüntüler…) kırıyordu; "57 GB'ın nerede olduğunu" söylemiyordu.
///
/// **Ölçüm arama dizininden gelir** ([SearchIndex] satırları): dizin zaten her
/// dosyanın yolunu ve boyutunu tutuyor, yani ağacı yeniden yürümeye gerek yok
/// (100 bin dosyalı bir telefonda o yürüyüş dakikalar sürüyor). Dizin yoksa ya
/// da boşsa yalnız **istenen klasörün altı** diskten yürünür — tüm depolama
/// değil, o dalın kendisi.
abstract final class FolderUsageScan {
  /// [root] klasörünün doğrudan çocuklarının dökümü.
  ///
  /// [indexPath] verilirse önce arama dizini denenir; sonuç boş çıkarsa
  /// (dizin yok/bayat/kapsamıyor) diske düşülür.
  static Future<FolderBreakdown> of(String root, {String? indexPath}) async {
    if (indexPath != null) {
      final fromIndex =
          await _run(_fromIndex, _UsageArgs(p.normalize(root), indexPath));
      if (fromIndex.children.isNotEmpty) return fromIndex;
    }
    return _run(_fromDisk, _UsageArgs(p.normalize(root), null));
  }

  static Future<R> _run<A, R>(R Function(A) fn, A arg) async {
    try {
      return await compute(fn, arg);
    } catch (_) {
      return fn(arg);
    }
  }
}

class _UsageArgs {
  final String root;
  final String? indexPath;
  const _UsageArgs(this.root, this.indexPath);
}

/// Yol [root]'un hemen altındaki hangi çocuğa düşüyor? (Değilse null.)
///
/// Yalnız ayraçtan sonraki İLK parça alınır: `/depo/DCIM/Camera/a.jpg`
/// `/depo` için `DCIM`tir, `Camera` değil — döküm bir seviyeliktir, alt
/// seviyeler o klasöre girilince hesaplanır.
String? childSegment(String root, String path) {
  // `p.isWithin` + `p.relative`: elle `substring` yapmak ayracı `/` varsaymak
  // demekti (bkz. [FsPaths.isInside]'daki 2026-07-27 tuzağı).
  if (!p.isWithin(root, path)) return null;
  final parts = p.split(p.relative(path, from: root));
  return parts.isEmpty ? null : parts.first;
}

FolderBreakdown _collect(
  String root,
  void Function(void Function(FsEntry)) forEachFile,
) {
  final bytes = <String, int>{};
  final files = <String, int>{};
  final isDir = <String, bool>{};
  var totalBytes = 0;
  var totalFiles = 0;

  forEachFile((entry) {
    if (entry.isDir) return;
    final seg = childSegment(root, entry.path);
    if (seg == null) return;
    bytes[seg] = (bytes[seg] ?? 0) + entry.sizeBytes;
    files[seg] = (files[seg] ?? 0) + 1;
    // Doğrudan kökün altındaki bir DOSYA ise adı yolun tamamıdır.
    isDir[seg] = isDir[seg] ?? (p.join(root, seg) != entry.path);
    totalBytes += entry.sizeBytes;
    totalFiles++;
  });

  final children = [
    for (final seg in bytes.keys)
      FolderUsage(
        path: p.join(root, seg),
        name: seg,
        isDir: isDir[seg] ?? true,
        bytes: bytes[seg] ?? 0,
        files: files[seg] ?? 0,
      ),
  ]..sort((a, b) => b.bytes.compareTo(a.bytes));

  return FolderBreakdown(
    root: root,
    children: children,
    totalBytes: totalBytes,
    totalFiles: totalFiles,
  );
}

FolderBreakdown _fromIndex(_UsageArgs args) {
  final path = args.indexPath;
  if (path == null || !File(path).existsSync()) return FolderBreakdown.empty;
  return _collect(args.root, (add) {
    forEachIndexRow(path, (entry) {
      add(entry);
      return true;
    });
  });
}

FolderBreakdown _fromDisk(_UsageArgs args) {
  final dir = Directory(args.root);
  if (!dir.existsSync()) return FolderBreakdown.empty;
  return _collect(args.root, (add) {
    walkFiles(dir, add, () {});
  });
}
