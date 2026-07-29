import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// **"Son açılma tarihi"** — bir dosyanın en son ne zaman açıldığı, TÜM dosya
/// türleri için (görüntü, video, ses, arşiv, belge…).
///
/// ## Niye ayrı bir kayıt (var olan "Son belgeler" listesinden bağımsız)
/// `AppState.recents` yalnız **belge** açılışlarını (Word/Excel/PDF/metin)
/// tutar ve en son 40'la sınırlıdır — "AI" sekmesindeki hızlı erişim listesi
/// için tasarlanmıştır. Kullanıcı isteği (2026-07-29): *"son açılma tarihi
/// tüm dosyalar içinde yapılabilmeli ayrı bir alanda"* — yani görüntü/video
/// dahil HER dosya türü ve sınırsız (dosya sistemde durduğu sürece) sayıda
/// kayıt, kendi ekranında. Bu yüzden ayrı, sadece yol→zaman eşleyen bir kayıt.
///
/// Etiketlerle (`file_tags.dart`) aynı desende: uygulamanın kendi dizininde
/// JSON, dosyanın içine yazılmaz, silinen dosyaların kayıtları yüklemede
/// temizlenir.
abstract final class OpenHistory {
  static const _fileName = 'open_history.json';

  static final Map<String, int> _byPath = {};

  /// Yükleme **Future'ı** paylaşılır (bool bayrak DEĞİL): [record] her açılışta
  /// çağrılır ve genellikle uygulamanın OpenHistory'ye dokunduğu İLK yer olur.
  /// Bayrak senkron olarak "yüklendi" işaretlenip gerçek disk okuması hâlâ
  /// sürüyorsa, `record` boş bellek üstüne yazıp var olan geçmişi SİLERDİ —
  /// bu, kullanıcının "geçmişim kayboldu" demesiyle sonuçlanacak ciddi bir
  /// hataydı. Future memoizasyonu, eşzamanlı çağıranların gerçekten aynı
  /// (bitmiş) yüklemeyi beklemesini garantiler.
  static Future<void>? _loadFuture;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// Diskten okur ve **artık var olmayan** dosyaların kayıtlarını atar.
  static Future<void> ensureLoaded() => _loadFuture ??= _load();

  static Future<void> _load() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      var dropped = false;
      for (final entry in raw.entries) {
        final key = '${entry.key}';
        final ms = (entry.value as num?)?.toInt();
        if (ms == null) continue;
        if (!File(key).existsSync()) {
          dropped = true;
          continue;
        }
        _byPath[key] = ms;
      }
      if (dropped) await _saveNow();
    } catch (_) {
      // Bozuk dosya sessizce yok sayılır: bu bir kolaylık kaydı, uygulamayı
      // kilitlememeli.
    }
  }

  static Future<void> _saveNow() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final tmp = File('$_path.tmp');
      await tmp.writeAsString(jsonEncode(_byPath), flush: true);
      await tmp.rename(_path);
    } catch (_) {}
  }

  /// [path] için "şimdi açıldı" damgası.
  ///
  /// Önce var olan geçmiş yüklenir, SONRA damga eklenip kaydedilir — sıra
  /// tersine çevrilirse yukarıdaki [_loadFuture] notundaki veri kaybı olur.
  /// Çağıran `await` etmek zorunda değil (dosya açma akışı bu yazmayı
  /// beklememeli); [EntryOpener] `unawaited` ile çağırır.
  static Future<void> record(String path) async {
    await ensureLoaded();
    _byPath[path] = DateTime.now().millisecondsSinceEpoch;
    await _saveNow();
  }

  /// [path]'in son açılma zamanı (ms); hiç açılmadıysa null.
  /// [ensureLoaded] önceden çağrılmış olmalı (bkz. `FileTags.forPath` deseni).
  static int? forPath(String path) => _byPath[path];

  /// Açılan **her** dosya (var olan) — en yeni önce.
  /// [ensureLoaded] önceden çağrılmış olmalı.
  ///
  /// Var olmayan dosyalar burada da elenir: liste açılırken taze bir kontrol
  /// (yükleme zamanındaki `_load` sırasında silinmiş bir dosya, ekran açıkken
  /// de silinmiş olabilir).
  static List<MapEntry<String, int>> all() {
    final out = _byPath.entries.where((e) => File(e.key).existsSync()).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  /// Bir kaydı listeden düşürür (dosya elle silindiğinde ekran tazelerken).
  static Future<void> remove(String path) async {
    await ensureLoaded();
    if (_byPath.remove(path) == null) return;
    await _saveNow();
  }

  /// Dosya uygulama içinden taşındı/adlandırıldı → kaydı yeni yola taşı.
  static Future<void> movePath(String from, String to) async {
    await ensureLoaded();
    final ms = _byPath.remove(from);
    if (ms == null) return;
    _byPath[to] = ms;
    await _saveNow();
  }

  /// Tüm geçmişi temizler (dosyaları SİLMEZ — yalnız "ne zaman açıldı" kaydı).
  static Future<void> clearAll() async {
    await ensureLoaded();
    _byPath.clear();
    await _saveNow();
  }

  /// Yalnız testler için: bellek durumunu sıfırlar.
  static void resetForTest() {
    _byPath.clear();
    _loadFuture = null;
  }
}
