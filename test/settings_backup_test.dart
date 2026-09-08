import 'package:dosya_okuyucu/services/settings_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-09-06 denetim turu: uygulama mağazadan değil GitHub Releases'ten
/// dağıtıldığı için otomatik ayar yedeği YOK; telefon değiştiren kullanıcı
/// 40'tan fazla ayarı elle kuruyordu.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ayarlar dışa aktarılıp geri yüklenir', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'ui_text_scale': 1.2,
      'fm_bookmarks': ['/depo/Belgeler', '/depo/Resimler'],
      'high_refresh': true,
      'trash_days': 30,
    });
    final prefs = await SharedPreferences.getInstance();
    final json = SettingsBackup.export(prefs, appVersion: '1.0.344');

    SharedPreferences.setMockInitialValues({});
    final fresh = await SharedPreferences.getInstance();
    final restored = await SettingsBackup.import(json, fresh);

    expect(restored, 5);
    expect(fresh.getString('theme_mode'), 'dark');
    expect(fresh.getDouble('ui_text_scale'), 1.2);
    expect(fresh.getStringList('fm_bookmarks'),
        ['/depo/Belgeler', '/depo/Resimler']);
    expect(fresh.getBool('high_refresh'), isTrue);
    expect(fresh.getInt('trash_days'), 30);
  });

  test('API anahtarı ve PIN yedeğe GİRMEZ', () async {
    SharedPreferences.setMockInitialValues({
      'ai_api_key': 'AIza-gizli',
      'ai_api_keys': ['AIza-1', 'AIza-2'],
      'fm_lock_pin': 'v1:abc',
      'app_lock_pin': 'v1:def',
      'account_email': 'biri@example.com',
      'theme_mode': 'light',
    });
    final prefs = await SharedPreferences.getInstance();
    final json = SettingsBackup.export(prefs);

    expect(json.contains('AIza'), isFalse);
    expect(json.contains('v1:abc'), isFalse);
    expect(json.contains('example.com'), isFalse);
    expect(json.contains('theme_mode'), isTrue);
  });

  test('gizli anahtar yedeğe elle EKLENSE bile geri yüklenmez', () async {
    // Yedek dosyası düz metin: kullanıcı (ya da başkası) elle satır ekleyebilir.
    const tampered = '{"format":1,"values":{"ai_api_key":"AIza-x",'
        '"theme_mode":"dark"}}';
    final prefs = await SharedPreferences.getInstance();
    final restored = await SettingsBackup.import(tampered, prefs);
    expect(restored, 1);
    expect(prefs.getString('ai_api_key'), isNull);
    expect(prefs.getString('theme_mode'), 'dark');
  });

  test('geri yükleme BİRLEŞTİRİR, yedekte olmayanı silmez', () async {
    SharedPreferences.setMockInitialValues({'yeni_ayar': 'kalmalı'});
    final prefs = await SharedPreferences.getInstance();
    await SettingsBackup.import(
        '{"format":1,"values":{"theme_mode":"dark"}}', prefs);
    expect(prefs.getString('yeni_ayar'), 'kalmalı');
    expect(prefs.getString('theme_mode'), 'dark');
  });

  test('bozuk dosyada anlaşılır hata', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(() => SettingsBackup.import('[1,2,3]', prefs),
        throwsFormatException);
    expect(() => SettingsBackup.import('{"format":1}', prefs),
        throwsFormatException);
  });

  test('bilinmeyen tür sessizce atlanır (ileri/geri uyumluluk)', () async {
    final prefs = await SharedPreferences.getInstance();
    final restored = await SettingsBackup.import(
        '{"format":99,"values":{"a":{"iç":"nesne"},"b":"tamam"}}', prefs);
    expect(restored, 1);
    expect(prefs.getString('b'), 'tamam');
  });

  test('önerilen ad tarihi taşır', () {
    expect(SettingsBackup.suggestedName(DateTime(2026, 9, 6)),
        'dosya-okuyucu-ayarlar-2026-09-06.json');
  });
}
