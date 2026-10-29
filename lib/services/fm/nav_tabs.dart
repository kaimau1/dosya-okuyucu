import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Alt gezinme çubuğunun kişiselleştirilmesi** (2026-10-18, kullanıcı ekran
/// görüntüsüyle: *"alt alandaki hızlı erişim butonları değiştirilebilir
/// olsun, kişi istediği şeyi oraya koyabilsin, sayı sınırı da 6 olsun"*).
///
/// Kurallar:
/// - **Dosyalar (pano) hep ilk ve kaldırılamaz.** Pano uygulamanın evi; geri
///   tuşu da oraya döner (bkz. `HomeScreen`). Kullanıcı onu çıkarabilseydi
///   uygulamadan çıkmanın ve ayarlara ulaşmanın yolu kaybolurdu.
/// - En fazla [maxTabs] sekme (Dosyalar dahil). Material'ın alt çubuğu 6'dan
///   fazlasında etiketleri okunmaz hâle getiriyor.
/// - Kimlikler kararlı dizeler (etiket değil): dil değişince düzen bozulmaz.
///   Bilinmeyen kimlik (eski sürümden kalma) sessizce atılır.
class NavTabs extends ChangeNotifier {
  NavTabs._();

  static final instance = NavTabs._();

  static const home = 'files';
  static const maxTabs = 6;

  /// Varsayılan çubuk — 2026-09-27'den beri gelen üçlü.
  static const defaults = [home, 'downloads', 'new'];

  /// Çubuğa konabilecek her şey (sıra = düzenleme sayfasındaki sıra).
  static const available = [
    home,
    'downloads',
    'new',
    'image',
    'video',
    'document',
    'audio',
    'archive',
    'apk',
    'important',
    'recent',
    'search',
    'ai',
    'smart',
    'bills',
    'vault',
    'jobs',
    'trash',
    'drive',
    'apps',
  ];

  static const _kTabs = 'nav_tabs';

  List<String> _tabs = List.of(defaults);
  bool _loaded = false;

  List<String> get tabs => List.unmodifiable(_tabs);

  bool get isDefault => listEquals(_tabs, defaults);

  bool get isFull => _tabs.length >= maxTabs;

  /// Kayıtlı listeyi kurallara uydurur: bilinmeyenler ve tekrarlar atılır,
  /// Dosyalar başa alınır, sınırın ötesi kesilir. Kayıt yoksa varsayılan.
  static List<String> sanitize(List<String>? saved) {
    if (saved == null) return List.of(defaults);
    final out = <String>[home];
    for (final id in saved) {
      if (out.length >= maxTabs) break;
      if (available.contains(id) && !out.contains(id)) out.add(id);
    }
    return out;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      _tabs = sanitize(p.getStringList(_kTabs));
      notifyListeners();
    } catch (_) {
      // Ayar okunamadı: varsayılan çubuk.
    }
  }

  Future<void> setTabs(List<String> tabs) async {
    _tabs = sanitize(tabs);
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kTabs, _tabs);
    } catch (_) {}
  }

  /// Sekme ekler; sınır doluysa ya da zaten varsa `false`.
  Future<bool> add(String id) async {
    if (isFull || _tabs.contains(id) || !available.contains(id)) return false;
    await setTabs([..._tabs, id]);
    return true;
  }

  /// Sekmeyi çıkarır (Dosyalar çıkarılamaz).
  Future<void> remove(String id) async {
    if (id == home) return;
    await setTabs([for (final t in _tabs) if (t != id) t]);
  }

  /// Dosyalar dışındaki sekmeleri yeniden sıralar ([from]/[to] Dosyalar
  /// HARİÇ listedeki konumlardır; [to] öğenin varacağı son dizin —
  /// `onReorderItem` sözleşmesi).
  Future<void> move(int from, int to) async {
    final rest = _tabs.skip(1).toList();
    if (from < 0 || from >= rest.length) return;
    final item = rest.removeAt(from);
    rest.insert(to.clamp(0, rest.length), item);
    await setTabs([home, ...rest]);
  }

  Future<void> reset() => setTabs(List.of(defaults));

  @visibleForTesting
  void debugReset() {
    _tabs = List.of(defaults);
    _loaded = false;
  }
}
