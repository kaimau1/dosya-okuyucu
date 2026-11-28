import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/viewer_priority.dart';
import '../../models/fs_entry.dart';
import 'fm_env.dart';
import 'fs_scan.dart';
import 'storage_stats.dart';

/// **Yeniler önbelleği** (2026-11-18, kullanıcı: *"yeni gelenler çok geç
/// yükleniyor; ilk açılışta hızlanabilirse hızlansın ama doğru çalışması
/// önemli"*).
///
/// **Kök:** ana ekran şeridi, Yeniler ekranı ve Aktar şeridi sıcak klasörlerin
/// TAMAMINI (DCIM + WhatsApp medyası: binlerce dosya) her biri ayrı ayrı
/// geziyordu; ilk sonuç gelene kadar şerit boş, ekran iskelet kalıyordu.
///
/// * **Tek tarama, ortak sonuç:** aynı anda gelen istekler süren taramaya
///   bağlanır ([scan]); tarama sürerken yeni istek geldiyse (dosya indi,
///   uygulamaya dönüldü) bitince bir tur daha atılır — yürüyüş İndirilenler'i
///   çoktan geçmiş olabilir, yeni dosya kaçmasın. Sonuç bellekte ([last]).
/// * **Anında ilk görüntü:** son taramanın en yeni [_persist] yolu diske
///   yazılır; açılışta [warm] bu yolları yalnız `stat` eder (silinenler düşer,
///   ağaç gezilmez). Ekran bunu hemen gösterir, ardından tam tarama gerçek
///   listeyi koyar. **Doğruluk tam taramada** — önbellek yalnız ilk kare.
abstract final class FreshCache {
  static const _key = 'fresh_cache_v1';
  static const _addedKey = 'fresh_added_v1';
  static const _persist = 60;
  static const _addedMax = 60;
  static const _addedWindowMs = 7 * 24 * 60 * 60 * 1000;

  /// Tarama sınırı = Yeniler ekranının sınırı; şeritler bunun başını alır.
  static const limit = 300;

  static List<FsEntry>? _last;
  static Future<List<FsEntry>>? _running;
  static int _wanted = 0;
  static List<String> _saved = const [];
  static Map<String, int>? _addedMem;

  /// Son tam taramanın sonucu (bu oturumda hiç taranmadıysa null).
  static List<FsEntry>? get last => _last;

  /// Tam tarama (izolatta). Süren varsa ona bağlanır; sürerken çağrıldıysa
  /// bitince bir tur daha atılır ve hepsi EN SON sonucu alır.
  static Future<List<FsEntry>> scan() {
    _wanted++;
    return _running ??= _loop().whenComplete(() => _running = null);
  }

  static Future<List<FsEntry>> _loop() async {
    List<FsEntry> out;
    int started;
    do {
      started = _wanted;
      out = await _scanOnce();
    } while (started != _wanted);
    return out;
  }

  static Future<Map<String, int>> _loadAdded() async {
    final mem = _addedMem;
    if (mem != null) return mem;
    final out = <String, int>{};
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_addedKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final cutoff = DateTime.now().millisecondsSinceEpoch - _addedWindowMs;
          for (final e in decoded.entries) {
            final ms = e.value is num ? (e.value as num).toInt() : 0;
            if (e.key is String && ms >= cutoff) {
              out[e.key as String] = ms;
            }
          }
        }
      }
    } catch (_) {
      // Bilinçli: tercihler okunamazsa bellek içi devam eder.
    }
    return _addedMem = out;
  }

  static Future<void> _saveAdded(Map<String, int> map) async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_addedKey, jsonEncode(map));
    } catch (_) {
      // Bilinçli: yazılamazsa oturum içi liste yine güncellenir.
    }
  }

  /// USB / indirme / kopyalama ile cihaza yeni eklenen dosyaları Yeniler'e işler.
  ///
  /// Kök neden: USB'den atılan kitap yıllar önce oluşturulmuş olabildiği için
  /// dosya sistemindeki `mtime` eskidir; `Yeniler`alnız `mtime`'a bakınca
  /// az önce USB'den atılan kitap orada hiç görünmüyordu.
  static Future<void> noteAdded(Iterable<String> paths) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = await _loadAdded();
    final newlyAdded = <FsEntry>[];
    for (final raw in paths) {
      if (raw.isEmpty) continue;
      final path = p.normalize(raw);
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) continue;
        map[path] = now;
        newlyAdded.add(FsEntry(
          path: path,
          name: p.basename(path),
          isDir: false,
          sizeBytes: stat.size,
          modifiedMs: now,
          accessedMs: stat.accessed.millisecondsSinceEpoch,
        ));
      } catch (_) {
        // Silinmiş/taşınmış dosya atlanır.
      }
    }
    if (newlyAdded.isEmpty) return;
    if (map.length > _addedMax) {
      final sorted = map.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      map
        ..clear()
        ..addEntries(sorted.take(_addedMax));
    }
    unawaited(_saveAdded(map));
    final current = _last;
    if (current != null) {
      final merged = _mergeAndSort(newlyAdded, current, map);
      _last = merged.take(limit).toList();
    } else {
      _last = _mergeAndSort(newlyAdded, const [], map);
    }
  }

  /// Yakın zamanda kopyalanıp eklenen canlı dosyaları döndürür.
  static Future<List<FsEntry>> addedEntries({
    FmCategory? category,
    String? root,
  }) async {
    final map = await _loadAdded();
    if (map.isEmpty) return const [];
    final cutoff = DateTime.now().millisecondsSinceEpoch - _addedWindowMs;
    final out = <FsEntry>[];
    final stale = <String>[];
    final normRoot = root == null ? null : p.normalize(root);
    for (final e in map.entries) {
      if (e.value < cutoff) {
        stale.add(e.key);
        continue;
      }
      if (normRoot != null &&
          e.key != normRoot &&
          !e.key.startsWith('$normRoot${p.separator}') &&
          !e.key.startsWith('$normRoot/')) {
        continue;
      }
      try {
        final file = File(e.key);
        if (!await file.exists()) {
          stale.add(e.key);
          continue;
        }
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) {
          stale.add(e.key);
          continue;
        }
        final entry = FsEntry(
          path: e.key,
          name: p.basename(e.key),
          isDir: false,
          sizeBytes: stat.size,
          modifiedMs: stat.modified.millisecondsSinceEpoch > e.value
              ? stat.modified.millisecondsSinceEpoch
              : e.value,
          accessedMs: stat.accessed.millisecondsSinceEpoch,
        );
        if (category == null || entry.category == category) {
          out.add(entry);
        }
      } catch (_) {
        stale.add(e.key);
      }
    }
    if (stale.isNotEmpty) {
      for (final s in stale) {
        map.remove(s);
      }
      unawaited(_saveAdded(map));
    }
    out.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    return out;
  }

  static List<FsEntry> _mergeAndSort(
    List<FsEntry> primary,
    List<FsEntry> secondary,
    Map<String, int> added,
  ) {
    final byPath = <String, FsEntry>{};
    for (final e in [...primary, ...secondary]) {
      final key = p.normalize(e.path);
      final addedMs = added[key];
      final normalized = addedMs != null && addedMs > e.modifiedMs
          ? FsEntry(
              path: e.path,
              name: e.name,
              isDir: e.isDir,
              sizeBytes: e.sizeBytes,
              modifiedMs: addedMs,
              accessedMs: e.accessedMs,
            )
          : e;
      byPath.putIfAbsent(key, () => normalized);
    }
    final list = byPath.values.toList();
    list.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    return list;
  }

  static Future<List<FsEntry>> _scanOnce() async {
    await ViewerPriority.waitUntilIdle();
    await FmEnv.ensureInit();
    await ViewerPriority.waitUntilIdle();
    final roots = StorageStats.hotFoldersForAll(FmEnv.phoneRoots);
    final scanned = roots.isEmpty
        ? const <FsEntry>[]
        : await FsScan.freshFiles(roots, limit: limit);
    final added = await addedEntries();
    final map = await _loadAdded();
    final all = _mergeAndSort(added, scanned, map).take(limit).toList();
    _last = all;
    unawaited(_save(all));
    return all;
  }

  /// İlk kare için: bellekteki son tarama, yoksa diskteki son yolların
  /// `stat`ı (en yeni önce). Hiç kayıt yoksa null.
  static Future<List<FsEntry>?> warm() async {
    final mem = _last;
    if (mem != null) return mem;
    try {
      final added = await addedEntries();
      final paths =
          (await SharedPreferences.getInstance()).getStringList(_key);
      if ((paths == null || paths.isEmpty) && added.isEmpty) return null;
      _saved = paths ?? const [];
      final stats = _saved.isEmpty
          ? const <FsEntry>[]
          : await FsScan.statPaths(_saved);
      final map = await _loadAdded();
      final combined = _mergeAndSort(added, stats, map);
      // Bu arada tam tarama bittiyse o doğrudur.
      return _last ?? combined;
    } catch (_) {
      // Bilinçli: önbellek yalnız hız; okunamazsa tam tarama beklenir.
      return null;
    }
  }

  static Future<void> _save(List<FsEntry> all) async {
    final paths = [
      for (final e in all.take(_persist))
        if (!e.isDir) e.path,
    ];
    if (listEquals(paths, _saved)) return;
    _saved = paths;
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, paths);
    } catch (_) {
      // Bilinçli: yazılamazsa bir sonraki açılış tam taramayı bekler.
    }
  }

  /// Gizlilik silme (Ayarlar → geçmişi temizle): yollar da gider.
  static Future<void> clear() async {
    _last = null;
    _saved = const [];
    _addedMem = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_addedKey);
    } catch (_) {
      // Bilinçli: silinemezse sonraki taramada üzerine yazılır.
    }
  }

  @visibleForTesting
  static void debugReset() {
    _last = null;
    _running = null;
    _wanted = 0;
    _saved = const [];
    _addedMem = null;
  }
}
