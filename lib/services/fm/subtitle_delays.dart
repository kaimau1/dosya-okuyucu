import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// **Altyazı gecikmesi — dosya başına hatırlanır.**
///
/// ## Niye (2026-09-06 denetim turu)
/// Oynatıcı altyazı gecikmesini yarım saniyelik adımlarla ayarlatıyor ama
/// değer **her açılışta sıfırlanıyordu** (`_subtitleOffsetMs = 0`). Gecikme
/// bir tercih değil, o dosyanın ÖZELLİĞİ: bir dizinin altyazısı 2,5 saniye
/// kaymışsa her bölümünde kaymış olur ve kullanıcı her açılışta aynı beş
/// dokunuşu tekrar yapıyordu.
///
/// Kayıt "kaldığın yerden devam" ile aynı desende: uygulamanın özel dizininde
/// küçük bir JSON, gecikmeli yazma (her dokunuşta diske gitmesin), en eski
/// kayıtlar budanıyor.
abstract final class SubtitleDelays {
  static const _fileName = 'subtitle_delays.json';

  /// En fazla kaç dosyanın gecikmesi tutulur. Sınır olmazsa dosya sessizce
  /// büyür; 300 kayıt bir dizi arşivi için fazlasıyla yeter.
  static const maxEntries = 300;

  /// Sıfır gecikme KAYDEDİLMEZ (ve varsa silinir): "ayarlamadım" ile
  /// "sıfıra ayarladım" aynı şeydir ve listeyi şişirmenin anlamı yok.
  static final Map<String, int> _byPath = {};
  static Future<void>? _loadFuture;
  static Timer? _saveTimer;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  static Future<void> ensureLoaded() {
    if (FmEnv.appSupportDir.isEmpty) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return;
      _byPath.clear();
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is num) _byPath['${entry.key}'] = value.toInt();
      }
    } catch (_) {
      // Bozuk kayıt bir güvence ağının kaybı; oynatıcı yine çalışır.
    }
  }

  /// [videoPath] için kayıtlı gecikme (ms). Yoksa 0.
  static int forPath(String videoPath) => _byPath[videoPath] ?? 0;

  /// Gecikmeyi kaydeder (0 ise kaydı siler).
  static void set(String videoPath, int milliseconds) {
    if (milliseconds == 0) {
      _byPath.remove(videoPath);
    } else {
      _byPath[videoPath] = milliseconds;
    }
    _scheduleSave();
  }

  /// Diske yazma **geciktirilir**: kullanıcı düğmeye arka arkaya basarken
  /// her dokunuşta dosya yazmanın anlamı yok.
  static void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () => unawaited(save()));
  }

  static Future<void> save() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      // En eskiler budanıyor: `Map` ekleme sırasını koruduğu için baştakiler
      // en eski kayıtlardır.
      while (_byPath.length > maxEntries) {
        _byPath.remove(_byPath.keys.first);
      }
      await File(_path).writeAsString(jsonEncode(_byPath), flush: true);
    } catch (_) {}
  }

  /// Testler için: belleği ve zamanlayıcıyı temizler.
  static void debugReset() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _loadFuture = null;
    _byPath.clear();
  }
}
