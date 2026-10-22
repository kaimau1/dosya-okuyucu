import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/media_resize.dart';

/// Boyutlandırmanın **son kullanılan ayarı** (Faz 14, G4g).
///
/// "Özgün dosyayı çöpe at" BİLEREK hatırlanmaz: geri alınamaz bir seçimin
/// bir sonraki işe kendiliğinden taşınması, kullanıcının fark etmeden
/// özgünlerini kaybetmesi demek olurdu.
abstract final class ResizeMemory {
  static const _key = 'resize.last';

  static Future<MediaResizeOptions?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return MediaResizeOptions.fromJson(jsonDecode(raw))
          .copyWith(replaceOriginal: false);
    } catch (_) {
      return null; // bozuk kayıt: varsayılanla açılır
    }
  }

  static Future<void> save(MediaResizeOptions options) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(options.copyWith(replaceOriginal: false).toJson()));
  }
}
