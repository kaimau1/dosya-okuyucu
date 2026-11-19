import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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
  bool _handleRight = false;
  bool _loaded = false;

  bool get showRecents => _showRecents;
  bool get showHandle => _showHandle;

  /// Tutamaç (ve menünün açıldığı kenar) sağda mı (2026-11-16, kullanıcı:
  /// "tutamaç sağa alınabilsin, kendi ayar yerinden").
  bool get handleRight => _handleRight;

  /// Tutamacı gizleyen ekran sayısı (video / foto görüntüleyici; 2026-11-16,
  /// kullanıcı: "tutamaç gizlensin ama işlevi devam etsin"). Yalnız çizim
  /// gizlenir; kenardan çekerek açma çalışır.
  final ValueNotifier<int> handleHiders = ValueNotifier(0);

  /// Tutamacı gizler; dönen işlev geri açar (bir kez çağrılır).
  ///
  /// TUZAK (MiniPlayerBar ile aynı): ekranın `initState`/`dispose`'u bir yapı
  /// turunun ortasında; katman gezginin ATASI olduğundan bildirim kareden
  /// sonraya bırakılır ("markNeedsBuild called during build").
  VoidCallback hideHandle() {
    _bumpHiders(1);
    var done = false;
    return () {
      if (done) return;
      done = true;
      _bumpHiders(-1);
    };
  }

  void _bumpHiders(int d) {
    void apply() => handleHiders.value = math.max(0, handleHiders.value + d);
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }
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
      if (s.startsWith('s:')) _handleRight = s == 's:r';
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
        's:${_handleRight ? 'r' : 'l'}',
      ]);
    } catch (_) {
      // Bilinçli: kayıt yazılamazsa bellekteki düzen geçerli kalır.
    }
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

  Future<void> setHandleRight(bool v) {
    _handleRight = v;
    return _save();
  }

  /// Menü satırlarında (gizliler hariç) sürükle-bırak: görünen sırayı
  /// değiştirir, gizlilerin yeri korunur.
  Future<void> moveVisible(int from, int to) {
    final all = [for (final t in tiles(includeHidden: true)) t.id];
    final shown = [
      for (final id in all)
        if (!isHidden(id)) id,
    ];
    if (from < 0 || from >= shown.length) return Future.value();
    final moved = shown.removeAt(from);
    shown.insert(to.clamp(0, shown.length), moved);
    var k = 0;
    return setOrder([
      for (final id in all) isHidden(id) ? id : shown[k++],
    ]);
  }

  Future<void> reset() {
    _order = [];
    _hidden = {};
    _showRecents = true;
    _showHandle = true;
    _handleRight = false;
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
    _handleRight = false;
    handleHiders.value = 0;
    _loaded = false;
  }
}
