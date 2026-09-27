import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// Yıldızlanmış bir sayfa.
class PageBookmark {
  /// 1 tabanlı sayfa.
  final int page;

  /// Oluşturulma zamanı (ms).
  final int at;

  const PageBookmark(this.page, this.at);
}

/// **Okurken sayfa yıldızlama** (2026-09-27, kullanıcı: *"okuma yapılırken
/// sayfa yıldızlama gibi özellikler olabilir"*).
///
/// Belgenin İÇİNE yazılmaz (PDF'i değiştirmek hem yavaş hem riskli — bkz.
/// 0 bayt bulgusu); uygulamanın kendi kaydında, belge yoluyla tutulur. Yol
/// değişirse ad + boyutla bulunur ([ReadingPositions] ile aynı kural).
abstract final class PdfBookmarks {
  static const _fileName = 'pdf_bookmarks.json';

  /// Belge başına en çok yer imi (aşırı büyümesin).
  static const maxPerDoc = 500;

  static final Map<String, _Doc> _byPath = {};
  static Future<void>? _loadFuture;
  static bool _loaded = false;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  static Future<void> ensureLoaded() => _loadFuture ??= _load();

  static Future<void> _load() async {
    if (FmEnv.appSupportDir.isEmpty) {
      try {
        await FmEnv.ensureInit();
      } catch (_) {}
    }
    if (FmEnv.appSupportDir.isEmpty) {
      _loadFuture = null;
      return;
    }
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      for (final e in raw.entries) {
        final v = e.value;
        if (v is! Map) continue;
        final marks = <PageBookmark>[
          for (final m in (v['m'] as List? ?? const []))
            if (m is Map && m['p'] is num)
              PageBookmark(
                  (m['p'] as num).toInt(), (m['t'] as num?)?.toInt() ?? 0),
        ];
        final key = '${e.key}';
        if (_byPath.containsKey(key)) continue; // bellekteki daha yeni
        _byPath[key] = _Doc(marks, (v['s'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {
      // Bozuk kayıt: kolaylık verisi, uygulamayı durdurmaz.
    } finally {
      _loaded = true;
    }
  }

  static _Doc? _find(String path, int? size) {
    final direct = _byPath[path];
    if (direct != null) return direct;
    if (size == null || size <= 0) return null;
    final name = p.basename(path);
    for (final e in _byPath.entries) {
      if (e.value.size == size && p.basename(e.key) == name) return e.value;
    }
    return null;
  }

  /// [path] belgesinin yer imleri, sayfa sırasıyla.
  static List<PageBookmark> of(String path, {int? size}) {
    final doc = _find(path, size);
    if (doc == null) return const [];
    return List.of(doc.marks)..sort((a, b) => a.page.compareTo(b.page));
  }

  static bool isMarked(String path, int page, {int? size}) =>
      _find(path, size)?.marks.any((m) => m.page == page) ?? false;

  /// Sayfayı yıldızlar ya da yıldızını kaldırır; yeni durumu döndürür.
  static Future<bool> toggle(String path, int page, {int size = 0}) async {
    await ensureLoaded();
    final doc = _find(path, size) ?? (_byPath[path] = _Doc([], size));
    final had = doc.marks.any((m) => m.page == page);
    if (had) {
      doc.marks.removeWhere((m) => m.page == page);
    } else {
      doc.marks.add(PageBookmark(page, DateTime.now().millisecondsSinceEpoch));
      if (doc.marks.length > maxPerDoc) doc.marks.removeAt(0);
    }
    await _save();
    return !had;
  }

  static Future<void> _save() async {
    if (FmEnv.appSupportDir.isEmpty || !_loaded) return;
    try {
      final data = {
        for (final e in _byPath.entries)
          if (e.value.marks.isNotEmpty)
            e.key: {
              if (e.value.size > 0) 's': e.value.size,
              'm': [
                for (final m in e.value.marks) {'p': m.page, 't': m.at},
              ],
            },
      };
      await File(_path).writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  /// Yalnız test.
  static void debugReset() {
    _byPath.clear();
    _loadFuture = null;
    _loaded = false;
  }
}

class _Doc {
  final List<PageBookmark> marks;
  final int size;

  _Doc(this.marks, this.size);
}
