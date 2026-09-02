import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/fm/usb/usb_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// **KULLANILAN ama TABLODA OLMAYAN anahtar bekçisi.**
///
/// Kök neden (2026-09-02): uzak gezgin yenilenirken `ctx.t('nas.delete')`
/// yazıldı; öyle bir anahtar yoktu. Hata ancak o ekranın widget testinde
/// çıktı — testi olmayan bir ekranda olsaydı kullanıcının telefonunda
/// çıkardı (hata ayıklamada `assert` patlar, yayında anahtarın kendisi
/// ekrana yazılır: "nas.delete").
///
/// `l10n_test` tablodaki eksikleri, `l10n_literals_test` tabloya hiç
/// girmemiş Türkçe metni yakalıyor. Bu üçüncüsü ters yönü kapatıyor:
/// **kaynakta çağrılan her anahtar tabloda var mı?**
void main() {
  test('kaynakta çağrılan her çeviri anahtarı tabloda VAR', () {
    // Yalnız düz dizeler: `t('usb.verdict_${v.name}')` gibi kurulan
    // anahtarlar burada eşleşmez (onlar aşağıdaki testte tek tek sınanıyor).
    final pattern = RegExp(r"""\.t\(\s*'([a-zA-Z0-9_.]+)'""");
    final known = AppStrings.keys.toSet();
    final missing = <String>{};
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        final key = match.group(1)!;
        // Nokta içermeyen eşleşmeler başka bir `t(...)` çağrısı olabilir
        // (ör. bir tarih biçimleyici); anahtarlar daima `alan.ad` biçiminde.
        if (!key.contains('.')) continue;
        if (!known.contains(key)) missing.add('$key (${file.path})');
      }
    }
    expect(missing, isEmpty,
        reason: 'tabloda olmayan anahtar(lar) çağrılıyor');
  });

  test('USB teşhis kararlarının HEPSİNİN metni var', () {
    // Bu anahtarlar `usb.verdict_${verdict.name}` diye kuruluyor; düz dize
    // taraması onları göremez. Yeni bir karar eklenirse metni de eklenmeli,
    // yoksa kullanıcı ekranda anahtar adını görür.
    for (final verdict in UsbVerdict.values) {
      expect(AppStrings.keys, contains('usb.verdict_${verdict.name}'),
          reason: '${verdict.name} için başlık yok');
      expect(AppStrings.keys, contains('usb.verdict_${verdict.name}_hint'),
          reason: '${verdict.name} için açıklama yok');
    }
  });
}
