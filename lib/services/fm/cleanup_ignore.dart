import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cleanup_advisor.dart';

/// **Yer aç — "Bir daha önerme"** (2026-11-20, kullanıcı: "yer aç
/// özelliğinde bir daha önerme seçeneği olmalı; her seferinde bakılmasın").
///
/// İki düzey: tüm öneri türü (ör. "Eski indirilenler") ya da tek dosya.
/// Cihazda kalır (SharedPreferences); Yer aç ekranının altından geri
/// alınabilir ("Gizlenenleri göster").
class CleanupIgnore {
  CleanupIgnore._();
  static final instance = CleanupIgnore._();

  static const _kIds = 'cleanup_ignore_ids';
  static const _kPaths = 'cleanup_ignore_paths';
  static const _kApps = 'cleanup_ignore_apps';

  final changes = ValueNotifier<int>(0);
  Set<String> _ids = {};
  Set<String> _paths = {};

  /// Uygulamalar ekranının önerisinde "Bir daha önerme" denen paketler (U6 b).
  /// Yer aç sayacına girmez; Uygulamalar ekranından geri getirilir.
  Set<String> _apps = {};
  bool _loaded = false;

  Set<String> get ignoredApps => _apps;

  int get count => _ids.length + _paths.length;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    _ids = (p.getStringList(_kIds) ?? const []).toSet();
    _paths = (p.getStringList(_kPaths) ?? const []).toSet();
    _apps = (p.getStringList(_kApps) ?? const []).toSet();
    _loaded = true;
    changes.value++;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kIds, _ids.toList());
    await p.setStringList(_kPaths, _paths.toList());
    await p.setStringList(_kApps, _apps.toList());
    changes.value++;
  }

  Future<void> ignoreSuggestion(String id) async {
    _ids.add(id);
    await _save();
  }

  Future<void> ignoreFile(String path) async {
    _paths.add(path);
    await _save();
  }

  Future<void> ignoreApp(String packageName) async {
    _apps.add(packageName);
    await _save();
  }

  Future<void> clearApps() async {
    _apps.clear();
    await _save();
  }

  Future<void> clear() async {
    _ids.clear();
    _paths.clear();
    await _save();
  }

  /// Gizlenen tür ve dosyaları düşürür; dosyası kalmayan öneri de düşer.
  List<CleanupSuggestion> apply(List<CleanupSuggestion> list) =>
      applyTo(list, ids: _ids, paths: _paths);

  /// Saf (birim testli).
  static List<CleanupSuggestion> applyTo(
    List<CleanupSuggestion> list, {
    required Set<String> ids,
    required Set<String> paths,
  }) {
    final out = <CleanupSuggestion>[];
    for (final s in list) {
      if (ids.contains(s.id)) continue;
      if (s.files.isEmpty || !s.files.any((f) => paths.contains(f.path))) {
        out.add(s);
        continue;
      }
      final kept = [
        for (final f in s.files)
          if (!paths.contains(f.path)) f,
      ];
      if (kept.isEmpty) continue;
      final vars = s.detailVars.containsKey('n')
          ? {...s.detailVars, 'n': kept.length}
          : s.detailVars;
      out.add(CleanupSuggestion(
        id: s.id,
        titleKey: s.titleKey,
        detailKey: s.detailKey,
        detailVars: vars,
        bytes: kept.fold<int>(0, (a, f) => a + f.sizeBytes),
        files: kept,
        safeByDefault: s.safeByDefault,
      ));
    }
    return out;
  }
}
