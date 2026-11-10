import 'package:dosya_okuyucu/services/app_update.dart';
import 'package:dosya_okuyucu/services/fm/remote/transfer_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sürüm karşılaştırma ANA.ARA.YAMA sırasıyla', () {
    expect(AppUpdate.isNewer('1.2.10', '1.2.9'), isTrue);
    expect(AppUpdate.isNewer('1.3.0', '1.2.99'), isTrue);
    expect(AppUpdate.isNewer('1.2.1', '1.2.1'), isFalse);
    expect(AppUpdate.isNewer('1.2.0', '1.2.1'), isFalse);
    expect(AppUpdate.isNewer('bozuk', '1.0.0'), isFalse);
    expect(AppUpdate.parseVersion('v2.0.3'), [2, 0, 3]);
  });

  test('sürüm JSON\'undan yalnız sürümlü APK seçilir, en yenisi', () {
    final info = AppUpdate.pickAsset({
      'assets': [
        {'name': 'dosya-okuyucu.apk', 'browser_download_url': 'u0', 'size': 1},
        {'name': 'dosya-okuyucu-v1.2.4.apk', 'browser_download_url': 'u1', 'size': 10},
        {'name': 'dosya-okuyucu-v1.2.5.apk', 'browser_download_url': 'u2', 'size': 20},
        {'name': 'app.aab', 'browser_download_url': 'u3', 'size': 30},
      ],
    });
    expect(info?.version, '1.2.5');
    expect(info?.url, 'u2');
    expect(info?.size, 20);
    expect(AppUpdate.pickAsset({'assets': []}), isNull);
    expect(AppUpdate.pickAsset('x'), isNull);
  });

  test('gönderim kaydı sonuç/yüzde/süre taşır; eski kayıt başarılı sayılır', () {
    final r = TransferRecord(
      incoming: false,
      path: '/a/b.pdf',
      name: 'b.pdf',
      size: 5,
      peer: 'PC',
      at: DateTime.fromMillisecondsSinceEpoch(1000),
      ok: false,
      percent: 42,
      duration: const Duration(seconds: 65),
    );
    final back = TransferRecord.fromJson(r.toJson())!;
    expect(back.ok, isFalse);
    expect(back.percent, 42);
    expect(back.duration, const Duration(seconds: 65));
    final old = TransferRecord.fromJson(
        {'i': false, 'p': '/x', 'n': 'x', 's': 1, 'k': 'Tel', 't': 0})!;
    expect(old.ok, isTrue);
    expect(old.percent, isNull);
    expect(old.duration, isNull);
  });

  test('sürüm notu: yalnız <!-- notlar --> kısmı, düz metin', () {
    const body = '## Sürüm 1.2.3\n\n<!-- notlar -->\n### ✨ Yenilikler\n'
        '- Galeri kartı\n\n### 🛠 Düzeltmeler\n- Eğik uyarısı\n'
        '<!-- /notlar -->\n\nHangi dosya…';
    expect(AppUpdate.extractNotes(body),
        '✨ Yenilikler\n• Galeri kartı\n\n🛠 Düzeltmeler\n• Eğik uyarısı');
    expect(AppUpdate.extractNotes('işaretsiz eski not'), '');
    expect(AppUpdate.extractNotes(null), '');
    final info = AppUpdate.pickAsset({
      'body': body,
      'assets': [
        {'name': 'dosya-okuyucu-v1.2.3.apk', 'browser_download_url': 'u', 'size': 5},
      ],
    });
    expect(info!.notes, contains('Galeri kartı'));
  });

  test('sürümlü APK yoksa başlıktaki sürüm + sabit ad', () {
    final info = AppUpdate.pickAsset({
      'name': 'Dosya Okuyucu nightly v1.2.12',
      'assets': [
        {'name': 'dosya-okuyucu.apk', 'browser_download_url': 'u', 'size': 9},
      ],
    });
    expect(info!.version, '1.2.12');
    expect(info.url, 'u');
  });
}
