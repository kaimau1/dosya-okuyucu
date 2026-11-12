import 'dart:io';

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

  group('G9.6 güncelleme bütünlüğü', () {
    const hex = 'a3f1c2d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
    test('gövdedeki sha256 satırı asset\'e bağlanır; GitHub digest yedek', () {
      final info = AppUpdate.pickAsset({
        'body': 'notlar\n<!-- sha256:dosya-okuyucu-v1.2.5.apk=${hex.toUpperCase()} -->',
        'assets': [
          {'name': 'dosya-okuyucu-v1.2.5.apk', 'browser_download_url': 'u', 'size': 1},
        ],
      });
      expect(info?.sha256, hex);
      final viaDigest = AppUpdate.pickAsset({
        'assets': [
          {
            'name': 'dosya-okuyucu-v1.2.5.apk',
            'browser_download_url': 'u',
            'size': 1,
            'digest': 'sha256:$hex',
          },
        ],
      });
      expect(viaDigest?.sha256, hex);
      final none = AppUpdate.pickAsset({
        'assets': [
          {'name': 'dosya-okuyucu-v1.2.5.apk', 'browser_download_url': 'u', 'size': 1, 'digest': 'md5:x'},
        ],
      });
      expect(none?.sha256, '');
    });

    test('yanlış özet reddedilir, doğrusu kabul', () async {
      final dir = await Directory.systemTemp.createTemp('upd');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/a.apk')..writeAsStringSync('abc');
      // sha256("abc")
      const ok = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
      expect(await AppUpdate.verifyDigest(f, ok), isTrue);
      expect(await AppUpdate.verifyDigest(f, ok.toUpperCase()), isTrue);
      expect(await AppUpdate.verifyDigest(f, hex), isFalse);
    });

    test('yalnız kendi deposunun https sürüm dosyası; yabancı ana makine yok', () {
      expect(
          AppUpdate.trustedAssetUrl(
              'https://github.com/kaimau1/dosya-okuyucu/releases/download/nightly/dosya-okuyucu-v1.2.5.apk'),
          isTrue);
      expect(
          AppUpdate.trustedAssetUrl(
              'http://github.com/kaimau1/dosya-okuyucu/releases/download/nightly/x.apk'),
          isFalse);
      expect(
          AppUpdate.trustedAssetUrl(
              'https://github.com/baskasi/dosya-okuyucu/releases/download/nightly/x.apk'),
          isFalse);
      expect(AppUpdate.trustedAssetUrl('https://evil.example/x.apk'), isFalse);
      expect(
          AppUpdate.trustedRedirect(
              Uri.parse('https://objects.githubusercontent.com/x')),
          isTrue);
      expect(
          AppUpdate.trustedRedirect(
              Uri.parse('https://release-assets.githubusercontent.com/x')),
          isTrue);
      expect(
          AppUpdate.trustedRedirect(Uri.parse('http://objects.githubusercontent.com/x')),
          isFalse);
      expect(AppUpdate.trustedRedirect(Uri.parse('https://evil.example/x')), isFalse);
    });
  });

  test('G12.4 en düşük güvenli sürüm işareti', () {
    const body = 'x\n<!-- min-guvenli: 1.2.40 -->\n';
    expect(AppUpdate.extractMinSafe(body), '1.2.40');
    expect(AppUpdate.extractMinSafe('yok'), isNull);
    expect(AppUpdate.securityRequiredFor(body, '1.2.39'), isTrue);
    expect(AppUpdate.securityRequiredFor(body, '1.2.40'), isFalse);
    expect(AppUpdate.securityRequiredFor(body, '1.3.0'), isFalse);
    expect(AppUpdate.securityRequiredFor(null, '1.0.0'), isFalse);
  });
}
