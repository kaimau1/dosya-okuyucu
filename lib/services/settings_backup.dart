import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// **Ayarları yedekle / geri yükle.**
///
/// ## Niye (2026-09-06 denetim turu)
/// Uygulamada 40'tan fazla ayar var (tema, yazı tipi ve ölçeği, dil, başlangıç
/// klasörü, yer imleri, sık kullanılan hedefler, oynatıcı tercihleri, çöp
/// kutusu kuralları, AI kapsamı…). Telefon değiştiren ya da uygulamayı
/// yeniden kuran kullanıcı **hepsini baştan kuruyordu**; uygulama mağazadan
/// değil GitHub Releases'ten geldiği için otomatik yedek de yok.
///
/// Yedek düz **JSON**: kullanıcı ne yedeklediğini açıp okuyabilir. Kapalı bir
/// biçim, "ayarlarım yedekte mi" sorusunu cevaplanamaz yapardı.
///
/// ## Yedeğe GİRMEYENLER — bilinçli
/// * **API anahtarları** (`ai_api_key*`) — yedek dosyası paylaşılabilir bir
///   şeydir (e-postayla kendine gönderirsin, buluta atarsın); içine bir
///   anahtar koymak onu sızdırmaktır.
/// * **PIN özetleri** (`fm_lock_pin`, `app_lock_pin`) — kilidin anlamı,
///   yedeği eline geçirenin onu geri yükleyip kilidi taşıyamaması.
/// * **Oturum/hesap bilgileri** (`account_*`) — başka bir cihaza taşınmamalı.
///
/// Bunlar ekranda da yazıyor: kullanıcı yedeğin neyi TAŞIMADIĞINI bilmeli,
/// yoksa yeni telefonda "anahtarım nerede" diye arar.
abstract final class SettingsBackup {
  /// Yedek biçiminin sürümü. Geri yüklerken okunuyor: ileride bir anahtarın
  /// anlamı değişirse eski yedek yine de tanınabilsin.
  static const formatVersion = 1;

  /// Yedeğe hiçbir koşulda girmeyen anahtar önekleri.
  static const secretPrefixes = <String>[
    'ai_api_key',
    'ai_api_keys',
    'gemini_key',
    'fm_lock_pin',
    'app_lock_pin',
    'account_',
    'firebase_',
  ];

  static bool isSecret(String key) =>
      secretPrefixes.any((prefix) => key.startsWith(prefix));

  /// Tercihleri JSON metnine çevirir.
  static String export(SharedPreferences prefs, {String? appVersion}) {
    final values = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      if (isSecret(key)) continue;
      final value = prefs.get(key);
      // `List<String>` JSON'da doğal olarak dizi; ötekiler zaten ilkel.
      if (value == null) continue;
      values[key] = value;
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': formatVersion,
      'app': appVersion ?? '',
      'created': DateTime.now().toIso8601String(),
      'values': values,
    });
  }

  /// Yedeği diske yazar; yolu döner.
  static Future<String> saveTo(
    String path,
    SharedPreferences prefs, {
    String? appVersion,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(export(prefs, appVersion: appVersion),
        flush: true);
    return path;
  }

  /// JSON metnini tercihlere yazar; **kaç ayarın** geri geldiğini döner.
  ///
  /// Bilinmeyen tür ya da gizli anahtar sessizce atlanır: ileriki bir sürümün
  /// yedeği eski bir sürüme yüklenebilmeli (ve tersi).
  ///
  /// Geri yükleme **birleştirir**, silmez: yedekte olmayan bir ayar olduğu
  /// gibi kalır. Aksi hâlde eski bir yedek, o günden sonra eklenmiş her
  /// ayarı sıfırlardı.
  static Future<int> import(String json, SharedPreferences prefs) async {
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('Yedek dosyası tanınmadı');
    }
    final values = decoded['values'];
    if (values is! Map) {
      throw const FormatException('Yedek dosyasında ayar bulunamadı');
    }
    var restored = 0;
    for (final entry in values.entries) {
      final key = '${entry.key}';
      if (isSecret(key)) continue;
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, [for (final v in value) '$v']);
      } else {
        continue;
      }
      restored++;
    }
    return restored;
  }

  /// Yedek dosyasını okuyup geri yükler.
  static Future<int> restoreFrom(
      String path, SharedPreferences prefs) async {
    return import(await File(path).readAsString(), prefs);
  }

  /// Yedek dosyası için önerilen ad: `dosya-okuyucu-ayarlar-2026-09-06.json`.
  static String suggestedName([DateTime? now]) {
    final d = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'dosya-okuyucu-ayarlar-'
        '${d.year}-${two(d.month)}-${two(d.day)}.json';
  }
}
