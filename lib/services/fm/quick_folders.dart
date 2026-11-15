import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// **Ana ekrandaki "Hızlı klasörler" listesinin kullanıcı ayarı**
/// (2026-11-15, kullanıcı: *"hızlı klasörlere şu an ekleme çıkarma
/// yapamıyorum"*).
///
/// Liste = standart klasörler (Kamera, İndirilenler…) − [hidden] + [added].
/// Standart klasör "çıkarılınca" gizlenir (yeniden eklenirse görünür);
/// kullanıcının eklediği klasör çıkarılınca kaydı silinir. Diskteki
/// klasöre hiç dokunulmaz.
class QuickFolders extends ChangeNotifier {
  QuickFolders._();

  static final instance = QuickFolders._();

  static const _key = 'quick_folders_v1';

  List<String> _added = const [];
  Set<String> _hidden = const {};
  bool _loaded = false;

  List<String> get added => List.unmodifiable(_added);

  /// `StorageStats.standardFolders` adayları (dizin adları) — diske
  /// bakmadan "standart mı" sorusu için.
  static const standardDirs = {
    'Download', 'Documents', 'DCIM', 'Pictures', 'Music', 'Movies', 'WhatsApp',
  };

  /// [path] bir birim kökünün ([roots]) doğrudan altındaki standart klasör mü?
  static bool isStandardPath(String path, Iterable<String> roots) =>
      standardDirs.contains(p.basename(path)) &&
      roots.any((r) => p.equals(r, p.dirname(path)));

  bool isHidden(String path) => _hidden.contains(p.normalize(path));

  bool isAdded(String path) =>
      _added.any((a) => p.equals(a, path));

  /// [path] şu an listede mi? [standard] = standart klasörlerden biri mi.
  bool contains(String path, {required bool standard}) =>
      standard ? !isHidden(path) : isAdded(path);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final map = jsonDecode(raw);
      if (map is! Map) return;
      _added = [
        for (final e in (map['added'] as List?) ?? const [])
          if (e is String) e,
      ];
      _hidden = {
        for (final e in (map['hidden'] as List?) ?? const [])
          if (e is String) e,
      };
      notifyListeners();
    } catch (_) {
      // Bozuk ayar: varsayılan liste (standart klasörler) ile başla.
    }
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode({'added': _added, 'hidden': _hidden.toList()}));
    } catch (_) {
      // Bilinçli: kayıt yazılamadı — bellekteki durum geçerli, sonraki kayıtta yeniden denenir.
    }
  }

  /// Listeye ekler. Standart klasörse gizliliği kalkar, değilse sona eklenir.
  Future<void> add(String path, {required bool standard}) async {
    await ensureLoaded();
    final n = p.normalize(path);
    if (standard) {
      _hidden = {..._hidden}..remove(n);
    } else if (!isAdded(n)) {
      _added = [..._added, n];
    }
    return _save();
  }

  /// Listeden çıkarır (klasörün kendisi diskte kalır).
  Future<void> remove(String path, {required bool standard}) async {
    await ensureLoaded();
    final n = p.normalize(path);
    if (standard) {
      _hidden = {..._hidden, n};
    }
    _added = [
      for (final a in _added)
        if (!p.equals(a, n)) a,
    ];
    return _save();
  }

  @visibleForTesting
  void debugReset() {
    _added = const [];
    _hidden = const {};
    _loaded = false;
  }
}
