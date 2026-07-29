import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../models/fs_entry.dart';
import 'fs_scan.dart';

/// Aynı içeriğe sahip dosyalar kümesi.
class DuplicateGroup {
  final int sizeBytes;
  final List<FsEntry> files;
  const DuplicateGroup(this.sizeBytes, this.files);

  /// Bir kopya bırakılıp diğerleri silinirse kazanılacak yer.
  int get wastedBytes => sizeBytes * (files.length - 1);
}

/// Yinelenen (birebir aynı) dosyaları bulur — yer açmanın en etkili yolu.
///
/// **Üç aşamalı, ucuzdan pahalıya:**
/// 1. Boyuta göre grupla (farklı boyut = kesinlikle farklı dosya; tek dosyalı
///    grup hemen elenir → diskten hiç okuma yapılmaz).
/// 2. Aday gruplarda **parmak izi**: baştan ve sondan 64 KB üzerinden FNV-1a
///    (saf Dart; `crypto` bağımlılığı eklemeye değmez).
/// 3. Parmak izi tutanları **bayt bayt** karşılaştır → yanlış pozitif YOK.
///    (Yalnız hash'e güvenip kullanıcının dosyasını sildirmek kabul edilemez.)
///
/// Tüm iş `Isolate.run` içinde: on binlerce dosyada disk okuma ana izleği
/// kilitlemesin.
abstract final class DuplicateFinder {
  /// 1 KB altındaki dosyalar yok sayılır (yüzlerce boş/küçük dosya listeyi
  /// doldurur, kazanç yok).
  static const defaultMinBytes = 1024;

  static Future<List<DuplicateGroup>> scan(
    List<String> roots, {
    int minBytes = defaultMinBytes,
    int maxGroups = 300,
  }) async {
    try {
      return await Isolate.run(() => scanSync(roots, minBytes, maxGroups));
    } catch (_) {
      return scanSync(roots, minBytes, maxGroups);
    }
  }

  /// **Belirli dosyalar** arasında yinelenenleri bulur (tüm depolamayı
  /// gezmeden). Galeride "gizlenen kopyaları gerçekten temizle" akışı bunu
  /// kullanır: ad+boyut ile *aday* bulunur, burada bayt bayt DOĞRULANIR —
  /// silme kararı asla tahmine dayanmamalı.
  static Future<List<DuplicateGroup>> scanPaths(
    List<FsEntry> entries, {
    int minBytes = 1,
    int maxGroups = 1000,
  }) async {
    try {
      return await Isolate.run(
          () => groupSync(entries, minBytes, maxGroups));
    } catch (_) {
      return groupSync(entries, minBytes, maxGroups);
    }
  }

  /// [scan]'in isolate'siz hâli (birim testleri bunu çağırır).
  static List<DuplicateGroup> scanSync(
    List<String> roots,
    int minBytes,
    int maxGroups,
  ) {
    // 1) boyuta göre grupla
    final all = <FsEntry>[];
    for (final root in roots) {
      walkFiles(Directory(root), all.add, () {});
    }
    return groupSync(all, minBytes, maxGroups);
  }

  /// Verilen girdiler arasında yinelenenleri bulur (üç aşamalı: boyut →
  /// parmak izi → bayt bayt). [scanSync] ve [scanPaths] ortak gövdesi.
  static List<DuplicateGroup> groupSync(
    List<FsEntry> entries,
    int minBytes,
    int maxGroups,
  ) {
    final bySize = <int, List<FsEntry>>{};
    for (final entry in entries) {
      if (entry.isDir || entry.sizeBytes < minBytes) continue;
      (bySize[entry.sizeBytes] ??= []).add(entry);
    }

    final groups = <DuplicateGroup>[];
    for (final entry in bySize.entries) {
      if (entry.value.length < 2) continue;

      // 2) parmak izine göre alt gruplar
      final byPrint = <int, List<FsEntry>>{};
      for (final file in entry.value) {
        final print = fingerprint(file.path, file.sizeBytes);
        if (print == null) continue; // okunamayan dosya atlanır
        (byPrint[print] ??= []).add(file);
      }

      // 3) bayt bayt doğrulama
      for (final candidates in byPrint.values) {
        if (candidates.length < 2) continue;
        final remaining = [...candidates];
        while (remaining.length > 1) {
          final head = remaining.removeAt(0);
          final same = <FsEntry>[head];
          remaining.removeWhere((other) {
            if (sameContent(head.path, other.path)) {
              same.add(other);
              return true;
            }
            return false;
          });
          if (same.length > 1) {
            groups.add(DuplicateGroup(entry.key, same));
          }
        }
      }
      if (groups.length >= maxGroups) break;
    }

    groups.sort((a, b) => b.wastedBytes.compareTo(a.wastedBytes));
    return groups.length > maxGroups ? groups.sublist(0, maxGroups) : groups;
  }

  /// Dosyanın baş+son 64 KB'ından üretilen 64-bit FNV-1a parmak izi.
  /// Okunamayan dosyada null.
  static int? fingerprint(String path, int size) {
    const window = 64 * 1024;
    RandomAccessFile? raf;
    try {
      raf = File(path).openSync();
      final head = raf.readSync(size < window ? size : window);
      Uint8List tail;
      if (size > window * 2) {
        raf.setPositionSync(size - window);
        tail = raf.readSync(window);
      } else {
        tail = Uint8List(0);
      }
      var hash = 0xcbf29ce484222325;
      void mix(int byte) {
        hash ^= byte;
        // 64-bit FNV prime; Dart int 64-bit (VM) → taşma sarmalı beklenen.
        hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
      }

      mix(size & 0xFF);
      for (final b in head) {
        mix(b);
      }
      for (final b in tail) {
        mix(b);
      }
      return hash;
    } catch (_) {
      return null;
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {}
    }
  }

  /// İki dosya birebir aynı mı? (Parçalar hâlinde okur; ilk farkta durur.)
  static bool sameContent(String a, String b) {
    RandomAccessFile? fa;
    RandomAccessFile? fb;
    try {
      final sa = File(a).lengthSync();
      final sb = File(b).lengthSync();
      if (sa != sb) return false;
      fa = File(a).openSync();
      fb = File(b).openSync();
      const chunk = 256 * 1024;
      var read = 0;
      while (read < sa) {
        final ba = fa.readSync(chunk);
        final bb = fb.readSync(chunk);
        if (ba.length != bb.length) return false;
        for (var i = 0; i < ba.length; i++) {
          if (ba[i] != bb[i]) return false;
        }
        if (ba.isEmpty) break;
        read += ba.length;
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        fa?.closeSync();
      } catch (_) {}
      try {
        fb?.closeSync();
      } catch (_) {}
    }
  }
}
