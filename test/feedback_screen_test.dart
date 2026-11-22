import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/settings/feedback_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hata / istek bildirimi (2026-11-22): giden metin anahtar, yol ve e-posta
/// içermez; tür ve sürüm başlıkta.
void main() {
  const tr = AppStrings(AppLanguage.tr);

  test('metin: tür başta, anahtar/yol arındırılır, cihaz satırı var', () {
    final key = 'AIza${'A' * 35}';
    final text = FeedbackScreen.compose(
      s: tr,
      kind: FeedbackKind.bug,
      message: 'Açılmıyor $key /storage/emulated/0/Belgeler/gizli.pdf',
      deviceLine: 'android 14',
      crashText: 'hata: $key',
    );
    expect(text.split('\n').first, 'Hata');
    expect(text, isNot(contains(key)));
    expect(text, isNot(contains('gizli.pdf')));
    expect(text, contains('android 14'));
  });

  test('konu satırı türü ve uygulama adını taşır', () {
    expect(FeedbackScreen.subject(tr, FeedbackKind.idea),
        startsWith('[İstek] Dosya Okuyucu'));
  });
}
