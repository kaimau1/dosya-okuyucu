// Play izin beyanı bekçisi (2026-11-02).
//
// `ci/AndroidManifest.xml`'deki ve eklentilerden birleşen her
// `uses-permission`, `docs/play/izin_beyanlari.md`'de bir `## ` başlığında
// geçmeli. 2026-11-01 taramasında Yakındakiler'in BLE / Wi-Fi / konum
// izinleri ve `QUERY_ALL_PACKAGES` belgede yoktu; Play formu eksik kalırdı.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kısa ad: `android.permission.CAMERA` → `CAMERA`,
/// `com.android.launcher.permission.INSTALL_SHORTCUT` → `INSTALL_SHORTCUT`.
String _short(String name) => name.substring(name.lastIndexOf('.') + 1);

final _usesPermission =
    RegExp(r'<uses-permission(?:-sdk-23)?\s+[^>]*android:name="([^"]+)"');

Set<String> _permissionsIn(String manifest) => {
      for (final m in _usesPermission.allMatches(manifest)) _short(m.group(1)!)
    };

/// Eklentilerin (`.dart_tool/package_config.json`) Android manifestlerinden
/// birleşen izinler. Paket önbelleği yoksa (çevrimdışı) boş döner.
Set<String> _pluginPermissions() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return {};
  final out = <String>{};
  final packages = (jsonDecode(config.readAsStringSync())
      as Map<String, dynamic>)['packages'] as List<dynamic>;
  for (final p in packages.cast<Map<String, dynamic>>()) {
    final root = Uri.parse(p['rootUri'] as String);
    if (!root.isAbsolute) continue; // kendi paketimiz
    final f = File.fromUri(root.resolve('android/src/main/AndroidManifest.xml'));
    if (f.existsSync()) out.addAll(_permissionsIn(f.readAsStringSync()));
  }
  return out;
}

void main() {
  final doc = File('docs/play/izin_beyanlari.md').readAsStringSync();
  final headings = [
    for (final l in const LineSplitter().convert(doc))
      if (l.startsWith('## ')) l,
  ];
  bool documented(String perm) =>
      headings.any((h) => RegExp('\\b$perm\\b').hasMatch(h));

  test('manifestteki her izin Play beyanında anlatılıyor', () {
    final perms =
        _permissionsIn(File('ci/AndroidManifest.xml').readAsStringSync());
    expect(perms, contains('MANAGE_EXTERNAL_STORAGE')); // ayrıştırıcı çalışıyor
    final missing = [for (final p in perms) if (!documented(p)) p]..sort();
    expect(missing, isEmpty,
        reason: 'docs/play/izin_beyanlari.md\'ye "## İZİN" başlığı ekle');
  });

  test('eklentilerden birleşen izinler de anlatılıyor', () {
    final perms = _pluginPermissions();
    if (perms.isNotEmpty) expect(perms, contains('QUERY_ALL_PACKAGES'));
    final missing = [for (final p in perms) if (!documented(p)) p]..sort();
    expect(missing, isEmpty,
        reason: 'eklenti manifestinden gelen izin belgede yok');
  });

  test('ayrıştırıcı', () {
    expect(
        _permissionsIn('<uses-permission android:name="android.permission.X"/>'
            '<uses-permission\n  android:name="com.a.permission.Y_Z"\n'
            '  android:maxSdkVersion="32"/>'),
        {'X', 'Y_Z'});
  });
}
