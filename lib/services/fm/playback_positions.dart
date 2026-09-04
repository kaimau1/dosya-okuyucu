import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// **"Kaldığın yerden devam et"** — video/ses dosyalarının bırakılma konumu.
///
/// Kullanıcı isteği 2026-09-03: *"video oynatma müzik oynatmada premium
/// geliştirmeler yap."* Bir film ya da uzun bir ders kaydı yarıda
/// bırakıldığında her açılışta başa dönmek, oynatıcıların en çok konuşulan
/// eksiği. Kayıt uygulamanın kendi dizininde JSON; dosyaya HİÇ dokunulmuyor
/// (etiketlerle aynı desen: `file_tags.dart`).
///
/// **Ne KAYDEDİLMEZ, bilinçli:**
/// * ilk 30 saniye — jenerikte bırakılan bir video "devam et" sormamalı;
/// * son %5 — bitirilmiş sayılır, bir daha açılınca baştan başlamalı;
/// * bir dakikadan kısa dosyalar (zil sesi, sesli not).
///
/// Kayıt [maxEntries] ile sınırlı: en eski dokunulan düşer. Sınırsız bir
/// sözlük yıllar içinde büyür ve hiçbir işe yaramaz.
abstract final class PlaybackPositions {
  static const _fileName = 'playback_positions.json';
  static const maxEntries = 300;

  /// Bu süreden kısa bir konum kaydedilmez.
  static const minPosition = Duration(seconds: 30);

  /// Dosyanın bu oranından sonrası "bitti" sayılır.
  static const endFraction = 0.95;

  /// **Ayar anahtarı** (`AppState.resumePosition`) — kapalıyken hiçbir şey
  /// kaydedilmez ve var olan kayıt kullanılmaz.
  ///
  /// Servis katmanı `AppState`e bağlanmasın diye bayrak burada duruyor;
  /// değeri ayar yüklenince/değişince `AppState` yazıyor. Kapatan kullanıcı
  /// dosyaların baştan açılmasını bekler — okumayı da kapatmak şart.
  static bool enabled = true;

  static final Map<String, _Entry> _byPath = {};
  static Future<void>? _loadFuture;
  static Timer? _saveTimer;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// Diskten okur. `appSupportDir` hazır değilse kilitlemez (bkz.
  /// `OpenHistory.ensureLoaded` — soğuk açılışta kayıt yüklemeden önce
  /// kilitlenmek tüm geçmişi silerdi).
  static Future<void> ensureLoaded() {
    if (FmEnv.appSupportDir.isEmpty) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final position = (value['p'] as num?)?.toInt() ?? 0;
        final duration = (value['d'] as num?)?.toInt() ?? 0;
        final at = (value['t'] as num?)?.toInt() ?? 0;
        if (position <= 0) continue;
        _byPath['${entry.key}'] = _Entry(position, duration, at);
      }
    } catch (_) {
      // Bozuk dosya: kolaylık kaydı, uygulamayı kilitlememeli.
    }
  }

  /// [path] için kayıtlı konum (yoksa null).
  static Duration? positionOf(String path) {
    if (!enabled) return null;
    final entry = _byPath[path];
    if (entry == null) return null;
    return Duration(milliseconds: entry.position);
  }

  /// Kayıtlı konumun toplam süreye oranı (0-1); bilinmiyorsa null.
  ///
  /// Listelerde "izlenme çubuğu" çizmek için: kullanıcı hangi videoyu yarım
  /// bıraktığını dosya adına bakarak hatırlamak zorunda kalmasın.
  static double? progressOf(String path) {
    final entry = _byPath[path];
    if (entry == null || entry.duration <= 0) return null;
    return (entry.position / entry.duration).clamp(0.0, 1.0);
  }

  /// Konumu kaydeder (kurallar için sınıf açıklamasına bakın).
  ///
  /// Diske yazma **geciktirilir**: konum saniyede bir güncelleniyor ve her
  /// seferinde dosya yazmak boşuna disk aşındırır.
  static void record(String path, Duration position, Duration duration) {
    if (!enabled || path.isEmpty) return;
    if (duration <= const Duration(minutes: 1)) return;
    if (position < minPosition) {
      // Başa sarıldıysa eski kaydı DÜŞÜR: kullanıcı baştan izlemeye karar
      // vermiş demektir, bir dahakine "devam et?" sormak yanlış olur.
      if (_byPath.remove(path) != null) _scheduleSave();
      return;
    }
    if (position.inMilliseconds >= duration.inMilliseconds * endFraction) {
      if (_byPath.remove(path) != null) _scheduleSave();
      return;
    }
    _byPath[path] = _Entry(
      position.inMilliseconds,
      duration.inMilliseconds,
      DateTime.now().millisecondsSinceEpoch,
    );
    _scheduleSave();
  }

  /// Kaydı siler (dosya bitirildi ya da kullanıcı "baştan başlat" dedi).
  static void clear(String path) {
    if (_byPath.remove(path) != null) _scheduleSave();
  }

  static void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 3), () => unawaited(save()));
  }

  /// Bekleyen kaydı hemen diske yazar (oynatıcı kapanırken çağrılıyor).
  static Future<void> save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      if (_byPath.length > maxEntries) {
        // En eskiye dokunulanlar düşer.
        final sorted = _byPath.entries.toList()
          ..sort((a, b) => b.value.at.compareTo(a.value.at));
        _byPath
          ..clear()
          ..addEntries(sorted.take(maxEntries));
      }
      final data = {
        for (final e in _byPath.entries)
          e.key: {'p': e.value.position, 'd': e.value.duration, 't': e.value.at},
      };
      await File(_path).writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Yazılamadı (izin/dolu disk): kolaylık kaydı, hata gösterilmez.
    }
  }

  /// Yalnız test: belleği ve zamanlayıcıyı sıfırlar.
  static void debugReset() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _byPath.clear();
    _loadFuture = null;
  }

  /// Yalnız test: kayıt sayısı.
  static int get count => _byPath.length;
}

class _Entry {
  final int position;
  final int duration;
  final int at;

  const _Entry(this.position, this.duration, this.at);
}
