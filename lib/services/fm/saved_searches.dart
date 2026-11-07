import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Kayıtlı tek arama.
class SavedSearch {
  final String name;
  final String query;

  /// Dosyaların içinde mi (içerik dizini) yoksa adında mı?
  final bool inContent;

  const SavedSearch(this.name, this.query, {this.inContent = false});

  Map<String, Object> toJson() => {'n': name, 'q': query, 'c': inContent};

  static SavedSearch? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final n = raw['n'], q = raw['q'];
    if (n is! String || q is! String || q.trim().isEmpty) return null;
    return SavedSearch(n, q, inContent: raw['c'] == true);
  }
}

/// **Kayıtlı aramalar** (Faz 41 / 3) — "son aramalar"dan farkı: kullanıcı
/// adlandırır, silinene dek kalır, içerik kipini de hatırlar. (AI tabanlı
/// "akıllı klasörler" ayrıca `SmartFolders`ta.)
abstract final class SavedSearches {
  static const prefKey = 'fm_saved_searches';
  static const max = 24;

  /// Saf: aynı sorgu+kip yeniden kaydedilirse adı güncellenip başa alınır.
  static List<SavedSearch> add(List<SavedSearch> list, SavedSearch s) => [
        s,
        ...list.where(
            (e) => !(e.query == s.query && e.inContent == s.inContent)),
      ].take(max).toList();

  static List<SavedSearch> remove(List<SavedSearch> list, SavedSearch s) =>
      list.where((e) => !(e.query == s.query && e.inContent == s.inContent)).toList();

  static Future<List<SavedSearch>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefKey);
      if (raw == null) return const [];
      return [
        for (final e in jsonDecode(raw) as List)
          ?SavedSearch.fromJson(e),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> store(List<SavedSearch> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          prefKey, jsonEncode([for (final s in list) s.toJson()]));
    } catch (_) {
      // Bilinçli: yazılamazsa yalnız bu oturumda geçerli.
    }
  }
}
