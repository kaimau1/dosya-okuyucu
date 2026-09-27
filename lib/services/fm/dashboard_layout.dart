import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Ana ekranı kişiselleştirme** (2026-09-27, kullanıcı: *"ana ekrandaki
/// düzen kişiselleştirilebilir olabilir, sırası ayarlanabilir, bazı şeyler
/// göster/gizle yapılabilir"*).
///
/// İki düzey: **bölümler** (bellek kartları, kategori kutuları, araçlar,
/// favoriler, hızlı klasörler) ve **kategori kutuları** (İndirilenler,
/// Görüntüler…). Her ikisinin sırası ve görünürlüğü saklanır. Kimlikler
/// kararlı dizelerdir (etiket değil — dil değişince düzen bozulmasın).
///
/// Bilinmeyen/yeni kimlikler (uygulama güncellenip yeni bir kutu eklenince)
/// kayıtlı sıranın SONUNA, görünür olarak eklenir: güncelleme kullanıcının
/// düzenini bozmaz, yeni özellik de gizli kalmaz.
class DashboardLayout extends ChangeNotifier {
  DashboardLayout._();

  static final instance = DashboardLayout._();

  static const sections = [
    'storage',
    'categories',
    'tools',
    'favorites',
    'quick',
  ];

  static const tiles = [
    'downloads',
    'important',
    'image',
    'video',
    'document',
    'audio',
    'archive',
    'apk',
    'new',
    'recent',
    'drive',
    'apps',
  ];

  static const _kSections = 'dash_sections';
  static const _kHiddenSections = 'dash_hidden_sections';
  static const _kTiles = 'dash_tiles';
  static const _kHiddenTiles = 'dash_hidden_tiles';

  List<String> _sectionOrder = List.of(sections);
  Set<String> _hiddenSections = {};
  List<String> _tileOrder = List.of(tiles);
  Set<String> _hiddenTiles = {};
  bool _loaded = false;

  List<String> get sectionOrder => List.unmodifiable(_sectionOrder);
  List<String> get tileOrder => List.unmodifiable(_tileOrder);
  bool sectionVisible(String id) => !_hiddenSections.contains(id);
  bool tileVisible(String id) => !_hiddenTiles.contains(id);

  /// Varsayılandan farklı mı? ("Varsayılana dön" düğmesi için.)
  bool get isCustomized =>
      _hiddenSections.isNotEmpty ||
      _hiddenTiles.isNotEmpty ||
      !listEquals(_sectionOrder, sections) ||
      !listEquals(_tileOrder, tiles);

  static List<String> _merge(List<String>? saved, List<String> known) {
    final out = <String>[
      for (final id in saved ?? const <String>[])
        if (known.contains(id)) id,
    ];
    for (final id in known) {
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      _sectionOrder = _merge(p.getStringList(_kSections), sections);
      _hiddenSections = {...?p.getStringList(_kHiddenSections)}
        ..retainAll(sections);
      _tileOrder = _merge(p.getStringList(_kTiles), tiles);
      _hiddenTiles = {...?p.getStringList(_kHiddenTiles)}..retainAll(tiles);
      notifyListeners();
    } catch (_) {
      // Ayar okunamadı: varsayılan düzen.
    }
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kSections, _sectionOrder);
      await p.setStringList(_kHiddenSections, _hiddenSections.toList());
      await p.setStringList(_kTiles, _tileOrder);
      await p.setStringList(_kHiddenTiles, _hiddenTiles.toList());
    } catch (_) {}
  }

  Future<void> moveSection(int from, int to) {
    _move(_sectionOrder, from, to);
    return _save();
  }

  Future<void> moveTile(int from, int to) {
    _move(_tileOrder, from, to);
    return _save();
  }

  Future<void> setSectionVisible(String id, bool visible) {
    visible ? _hiddenSections.remove(id) : _hiddenSections.add(id);
    return _save();
  }

  Future<void> setTileVisible(String id, bool visible) {
    visible ? _hiddenTiles.remove(id) : _hiddenTiles.add(id);
    return _save();
  }

  Future<void> reset() {
    _sectionOrder = List.of(sections);
    _tileOrder = List.of(tiles);
    _hiddenSections = {};
    _hiddenTiles = {};
    return _save();
  }

  /// `ReorderableListView` kuralı: aşağı taşırken hedef dizin bir fazladır.
  static void _move(List<String> list, int from, int to) {
    if (from < 0 || from >= list.length) return;
    var target = to > from ? to - 1 : to;
    target = target.clamp(0, list.length - 1);
    final item = list.removeAt(from);
    list.insert(target, item);
  }

  /// [items]'ı kayıtlı sıraya dizer ve gizlileri çıkarır ([idOf] kimlik).
  List<T> arrangeTiles<T>(List<T> items, String Function(T) idOf) {
    final byId = {for (final t in items) idOf(t): t};
    return [
      for (final id in _tileOrder)
        if (byId.containsKey(id) && tileVisible(id)) byId[id] as T,
      // Kimliği listede olmayan (yeni) kutular sona.
      for (final t in items)
        if (!_tileOrder.contains(idOf(t))) t,
    ];
  }

  @visibleForTesting
  void debugReset() {
    _sectionOrder = List.of(sections);
    _tileOrder = List.of(tiles);
    _hiddenSections = {};
    _hiddenTiles = {};
    _loaded = false;
  }
}
