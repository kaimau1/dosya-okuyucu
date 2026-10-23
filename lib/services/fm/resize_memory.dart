import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/media_resize.dart';

/// Kullanıcının **kaydettiği** boyutlandırma ön ayarı (Faz 14b, G4g):
/// "Profil 640×640", "Başvuru ≤ 200 KB" gibi adlı bir ayar.
class ResizePreset {
  final String name;
  final MediaResizeOptions options;

  const ResizePreset(this.name, this.options);

  Map<String, Object?> toJson() => {'name': name, 'options': options.toJson()};

  static ResizePreset? fromJson(Object? raw) {
    if (raw is! Map || raw['name'] is! String) return null;
    final name = (raw['name'] as String).trim();
    if (name.isEmpty) return null;
    return ResizePreset(name, MediaResizeOptions.fromJson(raw['options']));
  }
}

/// Boyutlandırmanın **son kullanılan ayarı** (Faz 14, G4g) ve kullanıcının
/// **kaydettiği ön ayarlar** (Faz 14b).
///
/// "Özgün dosyayı çöpe at" BİLEREK hatırlanmaz: geri alınamaz bir seçimin
/// bir sonraki işe kendiliğinden taşınması, kullanıcının fark etmeden
/// özgünlerini kaybetmesi demek olurdu. Ön ayarlarda da aynı kural.
abstract final class ResizeMemory {
  static const _key = 'resize.last';
  static const _presetsKey = 'resize.presets';

  /// Ön ayar sayısı tavanı — çip satırı levhayı kaplamasın.
  static const maxPresets = 8;

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

  static Future<List<ResizePreset>> presets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_presetsKey);
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (ResizePreset.fromJson(item) case final p?) p,
      ];
    } catch (_) {
      return const []; // bozuk kayıt: ön ayarsız açılır
    }
  }

  /// Aynı adlı ön ayar varsa üzerine yazılır (büyük/küçük harf duyarsız);
  /// tavan aşılırsa en eskisi düşer. Güncel liste döner.
  static Future<List<ResizePreset>> addPreset(
      String name, MediaResizeOptions options) async {
    final clean = name.trim();
    final list = [
      for (final p in await presets())
        if (p.name.toLowerCase() != clean.toLowerCase()) p,
      ResizePreset(clean, options.copyWith(replaceOriginal: false)),
    ];
    while (list.length > maxPresets) {
      list.removeAt(0);
    }
    await _write(list);
    return list;
  }

  static Future<List<ResizePreset>> removePreset(String name) async {
    final list = [
      for (final p in await presets())
        if (p.name != name) p,
    ];
    await _write(list);
    return list;
  }

  static Future<void> _write(List<ResizePreset> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _presetsKey, jsonEncode([for (final p in list) p.toJson()]));
  }
}
