import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/fm/fm_category_tile.dart';

/// **Yan menü** (2026-11-15, kullanıcı: *"soldan açılan yan menü olsun, tüm
/// kartlarımız orada liste hâlinde … her yerde hızlı erişim için ana menüye
/// dönmeden geçiş … kişi ihtiyacına göre düzenleyebilmeli, üstte son
/// açılanlar … ekranın 5'te 3'ünü aşmasın"*).
///
/// Kartların kaynağı ANA EKRANDIR: pano açılınca [tileSource]'u kaydeder,
/// menü her açılışta bunu çağırıp taze listeyi alır (kart verisi, sayılar ve
/// dokunma davranışı tek yerde — ana ekranla menü ayrışmaz). Pano henüz
/// kurulmadıysa (kilit/ilk açılış ekranı) [ready] `false` ve kenar tutamacı
/// çizilmez: kilit perdesinin üstünden menü açılamaz.
///
/// Menünün KENDİ düzeni (sıra, gizlenenler, son açılanlar şeridi, kenar
/// tutamacı) ana ekran düzeninden bağımsızdır: `side_menu_v1`.
class SideMenu extends ChangeNotifier {
  SideMenu._();

  static final instance = SideMenu._();

  static const _key = 'side_menu_v1';

  List<FmTileData> Function()? _source;

  /// Pano kurulu mu (menü açılabilir mi).
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// Menü şu an açık mı (tutamaç gizlenir).
  final ValueNotifier<bool> open = ValueNotifier(false);

  List<String> _order = [];
  Set<String> _hidden = {};
  bool _showRecents = true;
  bool _showHandle = true;
  bool _loaded = false;

  bool get showRecents => _showRecents;
  bool get showHandle => _showHandle;
  bool isHidden(String id) => _hidden.contains(id);

  void register(List<FmTileData> Function() source) {
    _source = source;
    ready.value = true;
  }

  void unregister(List<FmTileData> Function() source) {
    if (_source != source) return;
    _source = null;
    ready.value = false;
  }

  /// Panonun tüm kartları, menünün kayıtlı sırasında. [includeHidden]
  /// düzenleme levhası içindir.
  List<FmTileData> tiles({bool includeHidden = false}) {
    final all = _source?.call() ?? const <FmTileData>[];
    final byId = {for (final t in all) t.id: t};
    return [
      for (final id in _order)
        if (byId.containsKey(id) && (includeHidden || !isHidden(id))) byId[id]!,
      for (final t in all)
        if (!_order.contains(t.id) && (includeHidden || !isHidden(t.id))) t,
    ];
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key);
      if (raw != null) _decode(raw);
    } catch (_) {
      // Kayıt okunamazsa varsayılanlar.
    }
    notifyListeners();
  }

  // Biçim: ["o:<id>", …, "h:<id>", …, "r:1", "t:1"].
  void _decode(List<String> raw) {
    _order = [
      for (final s in raw)
        if (s.startsWith('o:')) s.substring(2),
    ];
    _hidden = {
      for (final s in raw)
        if (s.startsWith('h:')) s.substring(2),
    };
    for (final s in raw) {
      if (s.startsWith('r:')) _showRecents = s == 'r:1';
      if (s.startsWith('t:')) _showHandle = s == 't:1';
    }
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [
        for (final id in _order) 'o:$id',
        for (final id in _hidden) 'h:$id',
        'r:${_showRecents ? 1 : 0}',
        't:${_showHandle ? 1 : 0}',
      ]);
    } catch (_) {}
  }

  /// Düzenleme levhasının son sırası (tüm kimlikler, gizliler dahil).
  Future<void> setOrder(List<String> ids) {
    _order = List.of(ids);
    return _save();
  }

  Future<void> setHidden(String id, bool hidden) {
    hidden ? _hidden.add(id) : _hidden.remove(id);
    return _save();
  }

  Future<void> setShowRecents(bool v) {
    _showRecents = v;
    return _save();
  }

  Future<void> setShowHandle(bool v) {
    _showHandle = v;
    return _save();
  }

  Future<void> reset() {
    _order = [];
    _hidden = {};
    _showRecents = true;
    _showHandle = true;
    return _save();
  }

  @visibleForTesting
  void debugReset() {
    _source = null;
    ready.value = false;
    open.value = false;
    _order = [];
    _hidden = {};
    _showRecents = true;
    _showHandle = true;
    _loaded = false;
  }
}
