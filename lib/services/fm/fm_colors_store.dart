import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/app_colors.dart';
import 'fm_env.dart';

/// **Etiket ve klasör renkleri** (Faz 41 / madde 6, 2026-11-05).
///
/// Tek küçük JSON (`fm_colors.json`): `{"tags": {"iş": 5}, "folders":
/// {"/storage/…/Faturalar": 0}}` — değer [AppHues.labels] indeksi (renk
/// kodu değil: palet temayla birlikte değişebilir). Tembel yüklenir
/// (gezgin/etiket sayfası ilk açıldığında); okuma eşzamanlı haritadan.
abstract final class FmColorsStore {
  static const _fileName = 'fm_colors.json';
  static final Map<String, int> _tags = {};
  static final Map<String, int> _folders = {};
  static Future<void>? _loading;

  /// Değişim sayacı (renkli simgeler dar kapsamla yeniden çizilir).
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static String? debugDir;
  static String get _path =>
      p.join(debugDir ?? FmEnv.appSupportDir, _fileName);

  static Future<void> ensureLoaded() {
    if ((debugDir ?? FmEnv.appSupportDir).isEmpty) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final f = File(_path);
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return;
      decodeInto(raw, _tags, _folders);
      revision.value++;
    } catch (_) {
      // Bozuk dosya: renksiz başlanır.
    }
  }

  /// Saf: JSON → haritalar (geçersiz indeks atılır).
  static void decodeInto(
      Map<dynamic, dynamic> raw, Map<String, int> tags, Map<String, int> folders) {
    void read(Object? m, Map<String, int> into) {
      if (m is! Map) return;
      for (final e in m.entries) {
        final v = e.value;
        if (v is int && v >= 0 && v < AppHues.labels.length) {
          into['${e.key}'] = v;
        }
      }
    }

    read(raw['tags'], tags);
    read(raw['folders'], folders);
  }

  static Future<void> _save() async {
    try {
      await File(_path).writeAsString(
          jsonEncode({'tags': _tags, 'folders': _folders}));
    } catch (_) {}
    revision.value++;
  }

  static Color? tagColor(String tag) {
    final i = _tags[tag];
    return i == null ? null : AppHues.labels[i];
  }

  static Color? folderColor(String path) {
    final i = _folders[path];
    return i == null ? null : AppHues.labels[i];
  }

  static int? tagIndex(String tag) => _tags[tag];
  static int? folderIndex(String path) => _folders[path];

  /// [index] null = rengi kaldır.
  static Future<void> setTag(String tag, int? index) async {
    await ensureLoaded();
    if (index == null) {
      _tags.remove(tag);
    } else {
      _tags[tag] = index;
    }
    await _save();
  }

  static Future<void> setFolder(String path, int? index) async {
    await ensureLoaded();
    if (index == null) {
      _folders.remove(path);
    } else {
      _folders[path] = index;
    }
    await _save();
  }

  /// Klasör taşındı/yeniden adlandırıldı: rengi yeni yola geçer.
  static Future<void> moveFolder(String from, String to) async {
    await ensureLoaded();
    final v = _folders.remove(from);
    if (v == null) return;
    _folders[to] = v;
    await _save();
  }

  static void resetForTest() {
    _tags.clear();
    _folders.clear();
    _loading = null;
  }
}
