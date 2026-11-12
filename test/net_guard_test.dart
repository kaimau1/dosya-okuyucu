import 'dart:io';

import 'package:dosya_okuyucu/services/fm/remote/qr_transfer.dart';
import 'package:dosya_okuyucu/services/fm/remote/remote_fs.dart';
import 'package:dosya_okuyucu/services/offline_mode.dart';
import 'package:flutter_test/flutter_test.dart';

/// G10.4 (GUVENLIK_PLANI): çevrimdışı kipte `package:http` dışındaki ağ
/// açma yerleri de tek kapıdan (`NetGuard.allow`) geçer.
void main() {
  tearDown(() {
    OfflineMode.enabled = false;
    NetGuard.lastBlocked = null;
  });

  test('kip kapalıyken her şey serbest', () {
    NetGuard.allow('x');
    NetGuard.allow('x', host: 'example.com');
    expect(NetGuard.lastBlocked, isNull);
  });

  test('kip açıkken internet engellenir, yerel ağ serbest', () {
    OfflineMode.enabled = true;
    expect(() => NetGuard.allow('translate_model'),
        throwsA(isA<OfflineException>()));
    expect(NetGuard.lastBlocked, 'translate_model');
    expect(() => NetGuard.allow('sftp', host: 'files.example.com'),
        throwsA(isA<OfflineException>()));
    for (final h in ['192.168.1.20', 'nas.local', 'diskstation', 'router.home.arpa']) {
      NetGuard.allow('sftp', host: h);
    }
  });

  test('noktasız ad yerel, noktalı internet adı değil', () {
    expect(OfflineMode.isLocalHost('diskstation'), isTrue);
    expect(OfflineMode.isLocalHost('my-nas'), isTrue);
    expect(OfflineMode.isLocalHost('example.com'), isFalse);
    expect(OfflineMode.isLocalHost(''), isFalse);
  });

  test('QR alıcısı internet adresine kip açıkken bağlanmaz', () async {
    OfflineMode.enabled = true;
    await expectLater(QrReceiver.list(Uri.parse('http://8.8.8.8:1/')),
        throwsA(isA<OfflineException>()));
  });

  test('uzak dosya sistemi hatası çevrimdışı olarak eşlenir', () {
    expect(RemoteFs.mapError(const OfflineException()).error,
        RemoteError.offline);
  });

  // BEKÇİ: `package:http` dışından ağ açan her dosya ya kapıyı çağırır ya da
  // gerekçesiyle aşağıdaki listededir. Yeni ağ yolu = bu test kırmızı.
  test('http dışı ağ açan her yer NetGuard/OfflineMode denetliyor', () {
    final opens = RegExp(r'HttpClient\(\)|(?<![A-Za-z])Socket\.connect\(|'
        r'SSHSocket\.connect\(|FTPConnect\(|newClient\(|SmbConnect\.connect|'
        r'(?<!TranslateService)\.downloadModel\(|authorizeScopes\(');
    const exempt = {
      // Kapının kendisi: IOClient'ı OfflineAwareClient sarar.
      'lib/services/offline_mode.dart',
    };
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (exempt.contains(path)) continue;
      final src = f.readAsStringSync();
      if (!opens.hasMatch(src)) continue;
      if (src.contains('NetGuard.allow(') || src.contains('OfflineMode.enabled')) {
        continue;
      }
      missing.add(path);
    }
    expect(missing, isEmpty,
        reason: 'Bu dosyalar ağ açıyor ama çevrimdışı kipi denetlemiyor: '
            '${missing.join(', ')} — işe başlamadan NetGuard.allow(amaç, host: …).');
  });
}
