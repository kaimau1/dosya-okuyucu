import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _persist = 60;

  /// Tarama sınırı = Yeniler ekranının sınırı; şeritler bunun başını alır.
  static const limit = 300;

  static List<FsEntry>? _last;
  static Future<List<FsEntry>>? _running;
  static int _wanted = 0;
  static List<String> _saved = const [];

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

  static Future<List<FsEntry>> _scanOnce() async {
    await FmEnv.ensureInit();
    final roots = StorageStats.hotFoldersForAll(FmEnv.volumeRoots);
    final all = roots.isEmpty
        ? const <FsEntry>[]
        : await FsScan.freshFiles(roots, limit: limit);
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
      final paths =
          (await SharedPreferences.getInstance()).getStringList(_key);
      if (paths == null || paths.isEmpty) return null;
      _saved = paths;
      final stats = await FsScan.statPaths(paths);
      stats.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
      // Bu arada tam tarama bittiyse o doğrudur.
      return _last ?? stats;
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
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
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
  }
}
