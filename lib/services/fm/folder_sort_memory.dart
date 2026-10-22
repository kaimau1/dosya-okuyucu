import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/fs_entry.dart';

/// **Klasör başına sıralama** (Faz 17 / G3, 2026-10-22).
///
/// Gezginde sıralama tek global ayardı: "İndirilenler tarihe, Müzik ada
/// göre" yapılamıyordu. Sıralama menüsündeki "Yalnız bu klasör" anahtarı
/// açıkken seçim buraya yazılır; kaydı olmayan klasör global ayarı izler.
/// Bellekte eşleme; disk kaydı `fm_folder_sort` dizesi (`yol\tölçüt\työn`),
/// en çok [maxEntries] klasör (en eski kayıt düşer).
class FolderSortMemory extends ChangeNotifier {
  FolderSortMemory._();
  static final instance = FolderSortMemory._();

  static const _key = 'fm_folder_sort';
  static const maxEntries = 300;

  // LinkedHashMap: ekleme sırası = yaş (en eski önde).
  final Map<String, (FmSort, bool)> _map = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final line in prefs.getStringList(_key) ?? const <String>[]) {
        final parts = line.split('\t');
        if (parts.length != 3) continue;
        final sort = FmSort.values.where((s) => s.name == parts[1]);
        if (sort.isEmpty) continue; // eski/bilinmeyen ölçüt sessizce düşer
        _map[parts[0]] = (sort.first, parts[2] == '1');
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  static String _norm(String path) =>
      path.length > 1 && path.endsWith('/')
          ? path.substring(0, path.length - 1)
          : path;

  /// Klasörün kendi sıralaması; yoksa null (global ayar geçerli).
  (FmSort, bool)? of(String path) => _map[_norm(path)];

  Future<void> set(String path, FmSort sort, bool descending) async {
    final k = _norm(path);
    _map.remove(k);
    _map[k] = (sort, descending);
    while (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
    notifyListeners();
    await _save();
  }

  Future<void> clear(String path) async {
    if (_map.remove(_norm(path)) == null) return;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [
        for (final e in _map.entries)
          '${e.key}\t${e.value.$1.name}\t${e.value.$2 ? 1 : 0}',
      ]);
    } catch (_) {}
  }

  @visibleForTesting
  void debugReset() {
    _map.clear();
    _loaded = false;
  }
}
