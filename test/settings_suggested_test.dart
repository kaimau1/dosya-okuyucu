import 'package:dosya_okuyucu/screens/settings/settings_catalog.dart';
import 'package:dosya_okuyucu/widgets/fm/home_quick_row.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 40 / 5: önerilen ayarlar + 2026-11-05 alt panel varsayılanı.
void main() {
  test('eksik kurulum önce önerilir, en çok 4', () {
    final ids = suggestedSettingIds(
        hasApiKey: false, appLock: false, autoSave: false);
    expect(ids, ['api_key', 'auto_save', 'app_lock', 'ui_text_size']);
  });

  test('her şey kuruluysa görünüm ayarları', () {
    final ids =
        suggestedSettingIds(hasApiKey: true, appLock: true, autoSave: true);
    expect(ids, ['ui_text_size', 'skin', 'language']);
  });

  test('önerilen her kimlik katalogda var', () {
    final all = {
      for (final c in settingsCategories()) ...c.rows.map((r) => r.id)
    };
    for (final id in suggestedSettingIds(
        hasApiKey: false, appLock: false, autoSave: false, max: 99)) {
      expect(all, contains(id));
    }
  });

  test('alt panel sağ ek düğmesi varsayılan AI (Yer aç yerine)', () {
    expect(DockExtras.value.value.$2, 'ai');
  });
}
