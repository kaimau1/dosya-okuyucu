import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 16 / madde 6: Android 13+ uygulama başına dil listesi (`localeConfig`)
/// Dart'ın desteklediği dillerle AYNI olmalı. Biri eklenip öbürü unutulursa
/// sistem ayarında olmayan bir dil görünür ya da yeni dil seçilemez.
void main() {
  test('locales_config.xml = AppLanguageInfo.supportedLocales', () {
    final xml = File('ci/res/xml/locales_config.xml').readAsStringSync();
    final listed = RegExp(r'<locale android:name="([^"]+)"')
        .allMatches(xml)
        .map((m) => m[1])
        .toList();
    expect(listed,
        AppLanguageInfo.supportedLocales.map((l) => l.toLanguageTag()).toList());
  });

  test('manifest localeConfig\'i bağlıyor', () {
    final manifest = File('ci/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:localeConfig="@xml/locales_config"'));
  });
}
