import 'package:flutter/services.dart';

/// **Sesle yazma** (Faz 37 madde 6): cihazın konuşma tanıyıcısı
/// (`ci/Dikte.kt`, kanal `dosya/dictate`). Model indirme / APK yükü yok;
/// mikrofon izni tanıyıcı uygulamada. Tanıyıcı yoksa [DictationUnavailable].
class DictationUnavailable implements Exception {
  const DictationUnavailable();
}

abstract final class Dictation {
  static const _ch = MethodChannel('dosya/dictate');

  /// Testte kanal yerine (sonuç metni ya da null).
  static Future<String?> Function(String lang)? testHook;

  /// [lang]: BCP-47 (`tr-TR`, `en-US`, `ar`). Vazgeçilirse null.
  static Future<String?> listen({required String lang, String? prompt}) async {
    final hook = testHook;
    if (hook != null) return hook(lang);
    try {
      final r = await _ch.invokeMethod<String>(
          'start', {'lang': lang, 'prompt': prompt});
      final t = r?.trim();
      return t == null || t.isEmpty ? null : t;
    } on PlatformException catch (e) {
      if (e.code == 'unavailable') throw const DictationUnavailable();
      rethrow;
    } on MissingPluginException {
      throw const DictationUnavailable();
    }
  }
}
