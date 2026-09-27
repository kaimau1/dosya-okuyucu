import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_ops.dart';
import 'fm_env.dart';
import 'fs_events.dart';

/// Gizlenmiş bir öğe.
class HiddenItem {
  /// Kasadaki yolu.
  final String path;

  /// Gizlenmeden önceki yolu (geri yüklenecek yer).
  final String original;

  /// Gizlendiği an (ms).
  final int at;

  const HiddenItem(this.path, this.original, this.at);

  String get name => p.basename(original);
  bool get isDir => FileSystemEntity.isDirectorySync(path);
}

/// **Dosya gizleme** (2026-09-27, kullanıcı: *"dosyaları seçip gizleme
/// yapılabilmesi"*).
///
/// Gizlenen öğe ana bellekteki **gizli kasa klasörüne** taşınır
/// (`.DosyaOkuyucuGizli`, nokta ile başlar → dosya yöneticilerinde varsayılan
/// olarak görünmez; içinde `.nomedia` → galeri uygulamaları taramaz). Nereden
/// geldiği kasanın kendi dizininde tutulur, "Geri yükle" onu oraya döndürür.
/// Dizin kasanın İÇİNDE: uygulama silinip yeniden kurulsa da kayıt kaybolmaz.
///
/// **Dürüst sınır** (ekranda da yazılı): bu bir gizlilik perdesidir,
/// şifreleme değil — telefon bilgisayara bağlanıp gizli dosyalar gösterilirse
/// görülür. Kasa ekranı, ayarlanmışsa klasör kilidi PIN'iyle açılır.
abstract final class HiddenVault {
  static const folderName = '.DosyaOkuyucuGizli';
  static const _indexName = '.dizin.json';

  /// Test kancası: kasanın bulunduğu kök (varsayılan ana bellek).
  static String? debugRoot;

  static String get root => p.join(debugRoot ?? FmEnv.primaryRoot, folderName);

  static File get _indexFile => File(p.join(root, _indexName));

  static Future<Map<String, Map<String, Object?>>> _readIndex() async {
    try {
      final f = _indexFile;
      if (!await f.exists()) return {};
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return {};
      return {
        for (final e in raw.entries)
          if (e.value is Map)
            '${e.key}': Map<String, Object?>.from(e.value as Map),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeIndex(Map<String, Map<String, Object?>> index) =>
      _indexFile.writeAsString(jsonEncode(index), flush: true);

  static Future<void> _ensureRoot() async {
    final dir = Directory(root);
    if (!await dir.exists()) await dir.create(recursive: true);
    final nomedia = File(p.join(root, '.nomedia'));
    if (!await nomedia.exists()) await nomedia.writeAsString('');
  }

  /// [path] kasanın içinde mi?
  static bool contains(String path) =>
      p.isWithin(root, path) || p.equals(root, path);

  /// Öğeleri kasaya taşır; gizlenen sayıyı ve hataları döndürür.
  static Future<FmOpResult> hide(List<String> paths) async {
    await _ensureRoot();
    final wanted = [
      for (final path in paths)
        if (!contains(path)) path
    ];
    if (wanted.isEmpty) return const FmOpResult();
    final result = await FileOps.moveAll(wanted, root);
    if (result.transfers.isNotEmpty) {
      final index = await _readIndex();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final t in result.transfers) {
        index[p.basename(t.dest)] = {'o': t.source, 't': now};
      }
      await _writeIndex(index);
      FsEvents.changed([for (final t in result.transfers) t.source]);
    }
    return result;
  }

  /// Kasadaki öğeler (en son gizlenen başta).
  static Future<List<HiddenItem>> list() async {
    final dir = Directory(root);
    if (!await dir.exists()) return const [];
    final index = await _readIndex();
    final items = <HiddenItem>[];
    await for (final e in dir.list(followLinks: false)) {
      final name = p.basename(e.path);
      if (name == _indexName || name == '.nomedia') continue;
      final meta = index[name];
      final original = meta?['o'] is String
          ? meta!['o'] as String
          : p.join(FmEnv.primaryRoot, 'Download', name);
      final at = meta?['t'] is num ? (meta!['t'] as num).toInt() : 0;
      items.add(HiddenItem(e.path, original, at));
    }
    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  /// Öğeleri geldikleri yere geri taşır (klasör yoksa kurulur; aynı adda
  /// dosya varsa "(1)" eklenir).
  static Future<int> restore(List<HiddenItem> items) async {
    final index = await _readIndex();
    var restored = 0;
    for (final item in items) {
      final parent = p.dirname(item.original);
      try {
        await Directory(parent).create(recursive: true);
        final r = await FileOps.moveAll([item.path], parent);
        if (r.transfers.isEmpty) continue;
        final moved = r.transfers.first.dest;
        // Kasaya girerken çakışmadan dolayı "(1)" almış olabilir: özgün
        // adına döndür (o ad boşsa).
        final wantedPath = item.original;
        if (moved != wantedPath &&
            !File(wantedPath).existsSync() &&
            !Directory(wantedPath).existsSync()) {
          await FileSystemEntity.isDirectory(moved)
              ? await Directory(moved).rename(wantedPath)
              : await File(moved).rename(wantedPath);
        }
        index.remove(p.basename(item.path));
        restored++;
      } catch (_) {
        // Bu öğe geri gelemedi (hedef salt-okunur, SD kart çıkarılmış):
        // kasada kalır, kullanıcı yeniden deneyebilir.
      }
    }
    await _writeIndex(index);
    if (restored > 0) FsEvents.changed([for (final i in items) i.original]);
    return restored;
  }

  /// Dizinden [items]in kaydını düşer (öğeler silindikten sonra).
  static Future<void> forget(List<HiddenItem> items) async {
    final index = await _readIndex();
    for (final i in items) {
      index.remove(p.basename(i.path));
    }
    await _writeIndex(index);
  }
}
